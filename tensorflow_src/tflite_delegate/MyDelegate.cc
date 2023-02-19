
// https://www.tensorflow.org/lite/performance/implementing_delegate
// MyDelegate implements the interface of SimpleDelegateInterface.
// This holds the Delegate capabilities.

#include "tensorflow/lite/delegates/utils/simple_delegate.h"

#include "tensorflow/lite/builtin_ops.h"
#include "tensorflow/lite/kernels/kernel_util.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"

#include <vector>

#include <utility>

#include "dummy_delegate.h"
#include "Conv2D.h"
#include "tfacc_u8.h"

namespace tflite {
namespace dummy_test {

// My delegate kernel.
class MyDelegateKernel : public SimpleDelegateKernelInterface {
public:
    TfLiteStatus Init(TfLiteContext* context,
            const TfLiteDelegateParams* params) override {
        cma_malloc_init();
        // Save index to all nodes which are part of this delegate.
        inputs_.resize(params->nodes_to_replace->size);
        outputs_.resize(params->nodes_to_replace->size);
        builtin_code_.resize(params->nodes_to_replace->size);
        opparams_.resize(params->nodes_to_replace->size);
        for (int i = 0; i < params->nodes_to_replace->size; ++i) {
            const int node_index = params->nodes_to_replace->data[i];

            // Get this node information.
            TfLiteNode* delegated_node = nullptr;
            TfLiteRegistration* delegated_node_registration = nullptr;
            TF_LITE_ENSURE_EQ(
                    context,
                    context->GetNodeAndRegistration(context, node_index, &delegated_node,
                            &delegated_node_registration),
                            kTfLiteOk);
            inputs_[i].push_back(delegated_node->inputs->data[0]);	// input
            inputs_[i].push_back(delegated_node->inputs->data[1]);	// filter
            inputs_[i].push_back(delegated_node->inputs->data[2]);	// bias
            outputs_[i].push_back(delegated_node->outputs->data[0]);	// output
            builtin_code_[i] = delegated_node_registration->builtin_code;
            opparams_[i].per_channel_multiplier = nullptr;
            opparams_[i].convparam = delegated_node->builtin_data;
            //printf("Init(%d:%d) i:%d,%d,%d o:%d k:%d\n", i, node_index, inputs_[i][0], inputs_[i][1], inputs_[i][2],
            //				outputs_[i][0], builtin_code_[i]);
        }
        init_ = 0;
        //printf("Init : params->nodes_to_replace->size : %d\n", params->nodes_to_replace->size);

        return kTfLiteOk;
    }

    TfLiteStatus Prepare(TfLiteContext* context, TfLiteNode* node) override {
        if(init_) return kTfLiteOk;

        register_input_node(inputs_[0][0]);
        for (int i = 0; i < inputs_.size(); ++i) {
            TfLiteTensor *input  = &context->tensors[inputs_[i][0]];
            TfLiteTensor *filter = &context->tensors[inputs_[i][1]];
            TfLiteTensor *bias   = &context->tensors[inputs_[i][2]];
            TfLiteTensor *output = &context->tensors[outputs_[i][0]];
            const RuntimeShape& input_shape = GetTensorShape(input);
            const RuntimeShape& filter_shape = GetTensorShape(filter);
            const RuntimeShape& output_shape = GetTensorShape(output);
            const int inC   = input_shape.Dims(3);
            const int filH  = filter_shape.Dims(1);
            const int filW  = filter_shape.Dims(2);
            const int filC  = filter_shape.Dims(3);
            const int outC  = output_shape.Dims(3);
            int dwen = builtin_code_[i] == kTfLiteBuiltinDepthwiseConv2d;
            size_t filter_size;
            // alloc and reorder/copy filter
                //char* pt = (char*)cma_malloc(filter->bytes);
                //memcpy(pt, GetTensorData<int8>(filter), filter->bytes);
            char* pt =  reorder_filter(&filter_size, GetTensorData<int8>(filter), filH, filW, filC, inC, outC, dwen);
            filter->data.raw = pt;
            filter->bytes = filter_size;

            prepare_buffer_size(kTfaccOutput, output->bytes);
            prepare_buffer_size(kTfaccInput, input->bytes);
            prepare_buffer_size(kTfaccFilter, filter_size);
            prepare_buffer_size(kTfaccBias, bias->bytes);
            prepare_buffer_size(kTfaccQuant, bias->bytes);

            // alloc and copy bias
            pt = (char*)cma_malloc(bias->bytes);
            memcpy(pt, GetTensorData<int8>(bias), bias->bytes);
            bias->data.raw = pt;
            //if(i == 0) printf("Prepare %d: i:%p ft:%p o:%p fp:%p bp:%p\n", init_, input, filter, output, filter->data.raw, bias->data.raw);
        }
        cma_malloc_buffers();
        init_++;
        return kTfLiteOk;
    }

    TfLiteStatus Eval(TfLiteContext* context, TfLiteNode* node) override {
        //cma_malloc_buffers();
        //track_buf_flush();
        // Evaluate the delegated graph.
        //		printf("inputs_.size() : %d\n", inputs_.size());
        for (int i = 0; i < inputs_.size(); ++i) {
            TfLiteTensor *input  = &context->tensors[inputs_[i][0]];
            TfLiteTensor *filter = &context->tensors[inputs_[i][1]];
            TfLiteTensor *bias   = &context->tensors[inputs_[i][2]];
            TfLiteTensor *output = &context->tensors[outputs_[i][0]];
            if(output->data.raw == nullptr){
                output->data.raw = (char*)cma_malloc(output->bytes);    //new char[output->bytes];
                //printf("   alloc(%d) %d o:(%p)%d\n", i, outputs_[i][0], GetTensorData<int8>(output), output->bytes);
            }
            if(opparams_[i].per_channel_multiplier == nullptr){
                opparams_[i].per_channel_multiplier = (int32_t*)cma_malloc(bias->bytes); //new int32_t[output->dims->data[3]];
                OpParamsPrepare(context, input, filter, bias, output, &opparams_[i], builtin_code_[i]);
            }
            int dwen = builtin_code_[i] == kTfLiteBuiltinDepthwiseConv2d;
            TF_LITE_ENSURE_EQ(context,
                    Conv2DquantPerChannel(inputs_[i][0], dwen, &opparams_[i], input, filter, bias, output)
                    ,kTfLiteOk);
        }
        //printf("Eval : cma alloced: %d %x\n", get_cma_malloc_size(), get_cma_malloc_size());
        return kTfLiteOk;
    }

private:
    // Holds the indices of the input/output tensors.
    // inputs_[i] is list of all input tensors to node at index 'i'.
    // outputs_[i] is list of all output tensors to node at index 'i'.
    std::vector<std::vector<int>> inputs_, outputs_;
    // Holds the builtin code of the ops.
    // builtin_code_[i] is the type of node at index 'i'
    std::vector<int> builtin_code_;
    // Holds Convparams
    std::vector<OpParams> opparams_;
    int init_;
};
//-----

class MyDelegate : public SimpleDelegateInterface {
public:
    explicit MyDelegate(const DummyDelegateOptions& options)
    : options_(options) {}
    bool IsNodeSupportedByDelegate(const TfLiteRegistration* registration,
            const TfLiteNode* node,
            TfLiteContext* context) const override {
        // Only supports Conv2D and depthwiseConv2D ops.
        if (kTfLiteBuiltinConv2d != registration->builtin_code
                && kTfLiteBuiltinDepthwiseConv2d != registration->builtin_code) return false;
        //    if (kTfLiteBuiltinAdd != registration->builtin_code) return false;
        // This delegate only supports int8 types.
        //     printf("in:%d out:%d\n", node->inputs->size, node->outputs->size);
        // inputs: input,int8/filter,int8/bias,int32 outputs: output,int8
        auto& tensor = context->tensors[node->inputs->data[0]];	// input tensor
        return (tensor.type == kTfLiteInt8);
    }

    TfLiteStatus Initialize(TfLiteContext* context) override { 
        //printf("MyDelegate:Initialize()\n");
        return kTfLiteOk; 
    }

    const char* Name() const override {
        static constexpr char kName[] = "MyDelegate";
        return kName;
    }

    std::unique_ptr<SimpleDelegateKernelInterface> CreateDelegateKernelInterface()
    override {
        return std::make_unique<MyDelegateKernel>();
    }

    SimpleDelegateInterface::Options DelegateOptions() const override {
        // Use default options.
        return SimpleDelegateInterface::Options();
    }

private:
    const DummyDelegateOptions options_;
};

}  // namespace dummy_test
}  // namespace tflite


DummyDelegateOptions TfLiteDummyDelegateOptionsDefault() {
    DummyDelegateOptions options = {0};
    // Just assign an invalid builtin code so that this dummy test delegate will
    // not support any node by default.
    options.allowed_builtin_code = -1;
    return options;
}

// Creates a new delegate instance that need to be destroyed with
// `TfLiteDummyDelegateDelete` when delegate is no longer used by TFLite.
// When `options` is set to `nullptr`, the above default values are used:
TfLiteDelegate* TfLiteDummyDelegateCreate(const DummyDelegateOptions* options) {

    std::unique_ptr<tflite::dummy_test::MyDelegate> dummy(
            new tflite::dummy_test::MyDelegate(
                    options ? *options : TfLiteDummyDelegateOptionsDefault()));
    return tflite::TfLiteDelegateFactory::CreateSimpleDelegate(std::move(dummy));
}

// Destroys a delegate created with `TfLiteDummyDelegateCreate` call.
void TfLiteDummyDelegateDelete(TfLiteDelegate* delegate) {
    tflite::TfLiteDelegateFactory::DeleteSimpleDelegate(delegate);
}
