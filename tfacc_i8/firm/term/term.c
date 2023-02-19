#include <stdio.h>		/* Standard input/output definitions */
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/poll.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/ioctl.h>

speed_t
baudcode (int baud)
{
    switch (baud) {
    case 115200:
	return B115200;
    case 230400:
	return B230400;
    case 460800:
	return B460800;
    case 500000:
	return B500000;
    case 576000:
	return B576000;
    case 921600:
	return B921600;
    case 1000000:
	return B1000000;
    case 1152000:
	return B1152000;
    case 1500000:
	return B1500000;
    case 2000000:
	return B2000000;
    case 2500000:
	return B2500000;
    case 3000000:
	return B3000000;
//      case 3500000:   return B3500000;
//      case 4000000:   return B4000000;
    default:
	printf (" *** baud rate %d not defined.\n", baud);
	printf ("    fall back to 115200\n");
	return B115200;
    }
}

//char *dev = "/dev/serial/by-id/usb-Silicon_Labs_CP2104_USB_to_UART_Bridge_Controller_009D4050-if00-port0";
char *dev[] = {
//	"/dev/serial/by-id/usb-Xilinx_JTAG+Serial_1234-oj1-if01-port0",
//	"/dev/ttyUSB3",
//	"/dev/ttyUSB2",
//	"/dev/ttyUSB1",
	"/dev/ttyUSB0",
	};
#define Ndev	(sizeof(dev)/sizeof(char*))

int
open_serial (int brate)
{
    struct termios tios;
    int i, fd;
    speed_t baud = baudcode (brate);

    for(i = 0; i < Ndev; i++){
	fd = open (dev[i], O_RDWR);
	if(fd != -1) break;
    }

    if (fd < 0) {
//	fprintf (stderr, "Unable to open %s\n", dev);
    } else {
	printf ("*** open '%s'\n", dev[i]);
	tcgetattr (fd, &tios);
	cfmakeraw (&tios);
	cfsetospeed (&tios, baud);
	cfsetispeed (&tios, baud);
	tcsetattr (fd, TCSANOW, &tios);
    }

    return fd;
}

#define ETB     '\027'		// End of Transfer Block
#define EOT     '\004'		// End of Transfer
#define XON     '\021'		// X-on
#define NUL     '\0'		// NULL


#define STDIN   0
#define STDOUT  1
FILE *ofp;
FILE *pfp = NULL;

struct termios inittios;

void
init_term ()
{
    struct termios tios;
    tcgetattr (STDIN, &tios);
    inittios = tios;

    tios.c_lflag &= ~ISIG;      /* no kbd interrupt     */
    tios.c_lflag &= ~ECHO;	/* no echo      */
    tios.c_lflag &= ~ICANON;	/* raw mode (no buffered)       */

    tios.c_iflag &= ~IXON;	/* no x-on      */
    tios.c_iflag &= ~IXOFF;	/* no x-off     */

    tios.c_cc[VMIN] = 1;	// block
    tios.c_cc[VTIME] = 0;

    tcsetattr (STDIN, TCSANOW, &tios);
}

void deinit_term()
{
    tcsetattr (STDIN, TCSANOW, &inittios);
}

static int uartfd;

void
tx_data (char c)
{
    if(write (uartfd, &c, 1));
}

void
tx_datan (char *buf, int n)
{
    while(n--) tx_data(*buf++);
//write (uartfd, buf, n);
}

int
rx_data ()
{
    char c;
    if(read (uartfd, &c, 1));
    return c;
}

void
tx_str (char *s)
{
    char c;
    while ((c = *s++)) {
	tx_data (c);
    }
}

int get_key()	// get keyboard in
{
	int rv;
	char c;
	rv = read(STDIN, &c, 1);
	return rv ? c : 0;
}

void
dump (char c)
{
    static int i = 0;
    static char buf[80];
    int j;

    buf[i] = c;
    i = (i + 1) % 16;
    if (i == 0) {
	for (j = 0; j < 16; j++) {
	    if (isprint (buf[j]))
		putchar (buf[j]);
	    else
		putchar ('.');
	}
	putchar ('\n');
    }
    printf ("%02x ", c);
}

//B9600
//B19200
//B38400

//int s_brk = 0;

int
main (int argc, char *argv[])
{
    struct pollfd ufds[3];
    int i, dbg = 0;
    char c, fn[201], str[201];
    FILE *sfp = NULL;
    FILE *ifp = NULL;
    int cc = 0, csum;
    int XOFF = 0, bytes = 0;
    int baud = 115200;
//    int baud = 2000000;

    ofp = stderr;

    for (i = 1; i < argc; i++) {
	if (!strcmp (argv[i], "-debug"))
	    dbg = 1;
	else if (!strcmp (argv[i], "115200"))
	    baud = 115200;
	else if (!strcmp (argv[i], "1M"))
	    baud = 1000000;
	else if (!strcmp (argv[i], "2M"))
	    baud = 2000000;
	else if (!strcmp (argv[i], "3M"))
	    baud = 3000000;
	else
	    baud = atoi (argv[i]);
    }
    printf("Ctrl+Alt+c for exit.\n");

start:
    uartfd = open_serial (baud);
    if(uartfd < 0) {
	sleep(1);
	goto start;
    }
    init_term ();

//    ioctl(uartfd, TIOCSBRK);	// enter BREAK state, TXD -> low	tty_ioctl
//    fprintf (stderr, "\n==== break ...");
//    s_brk = 1;

    ufds[0].fd = STDIN;		// stdin
    ufds[0].events = POLLIN;
    ufds[1].fd = uartfd;		// serialport
    ufds[1].events = POLLIN;	// | POLLOUT;

    while (poll (ufds, 2, -1) > 0) {
	if (ufds[0].revents & POLLIN) {	// stdin data
	    c = get_key();
	    if (c == '\033') {
		if (ofp != stderr) {
		    pclose (ofp);
		    ofp = stderr;
		}
		if (sfp) {
		    fclose (sfp);
		    sfp = NULL;
		}
		c = get_key();
		if(c == 0x02){		// Ctrl,Alt,B
		    //s_brk = !s_brk;
		    //if (s_brk) {
		    //	ioctl (ufds[1].fd, TIOCSBRK);
		    //	fprintf (stderr, "\n==== break ...");
		    //} else {
		    //	ioctl (ufds[1].fd, TIOCCBRK);
		    //	fprintf (stderr, " resume ====\n");
		    //}
		}else if(c == 0x03){	// Ctrl,Alt,C
		    printf("\n");
		    deinit_term();
		    exit(0);
		}else{
		    tx_data ('\033');
		    tx_data (c);
		    if(c == '['){	// CSI
		      while(1){
			c = get_key();
			tx_data (c);
			if(c == '~' || isalpha(c)) break;	// terminate
		      }
		    }
		}
	    } else {
		tx_data (c);
	    }
	//    ufds[1].events |= POLLOUT;
	}
	if (ufds[1].revents & POLLIN) {	// uart rx data
	    int i = 0;
	    c = rx_data ();
	    //if(c == '$' && s_brk){
		//s_brk = 0;
		//ioctl (ufds[1].fd, TIOCCBRK);
		//fprintf (stderr, " resume ====\n");
	    //}
	    //if (c == '\0' && !s_brk) {
		//s_brk = 1;
		//ioctl (ufds[1].fd, TIOCSBRK);
		//fprintf (stderr, "\n==== break received, enter break ...");
	    //}
	    if (c == '\033') {
		c = rx_data ();
		if (c == '<') {	// download S-format file
		    XOFF = 0;
		    bytes = 0;
		    while ((c = rx_data ()) != '\n') {
			if (!isspace (c))
			    fn[i++] = c;
		    }
		    fn[i] = '\0';
		    if (*fn == '\0')
			strcpy (fn, "prog.mot");
		    sfp = fopen (fn, "r");
		    if (!sfp)
			sfp = fopen (strcat (fn, ".mot"), "r");
		    if (sfp != NULL) {
			int bc = 0;
			char sbuf[1024];
			csum = 0;
			do {
			    c = fgetc (sfp);
			    if (bc >= 1024 || c == EOF) {
				tx_datan (sbuf, bc);
				bc = 0;
				tx_data (ETB);
				while (rx_data () != XON) {
				}
				fputc ('.', stderr);
				if (c == EOF)
				    break;
			    }
			    sbuf[bc++] = c;
			    bytes++;
			    csum += c;
			} while (1);
			fclose (sfp);
			sfp = NULL;
			tx_data (EOT);
			fprintf (stderr, "\n[%d bytes tfr    cs:%d]", bytes, csum);
		    } else {
			fprintf (stdout, " file '%s' not found.\n", fn);
			tx_str ("S70500002000DA\n");
			tx_data (EOT);
		    }
		//} else if (c == '>') {	// plot data
		//    if (!pfp) {
		//	pfp = popen ("./plt", "w");
		//	if (!pfp)
		//	    fprintf (stdout, " './plt' can't open.\n");
		//    }
		//    ofp = pfp;
		} else if (c == 's') {	// pipe input
		    if ((ifp = popen ("sns/sns", "r")) == NULL) {
			fprintf (stdout, " 'sns/sns' can't open.\n");
		    } else {
			if ((c = fgetc (ifp)) != EOF) {
			    tx_data (c);
			    ufds[1].events |= POLLOUT;
			} else {
			    pclose (ifp);
			    ifp = NULL;
			}
		    }
		} else if (c == 'q') {	// plot end
		    if (ofp != stderr) {
			//      pclose(ofp);
			ofp = stderr;
		    }
		} else if (c == '+') {	// save file
		    while ((c = rx_data ()) != '\n') {
			if (!isspace (c))
			    fn[i++] = c;
		    }
		    fn[i] = '\0';
		    if (*fn == '\0')
			strcpy (fn, "save.dat");
		    if ((sfp = fopen (fn, "w")) != NULL) {
			while ((c = rx_data ()) != '\a') {	// terminate
			    if (!sfp)
				break;
			    fputc (c, sfp);
			}
			if (sfp)
			    fclose (sfp);
			sfp = NULL;
		    } else {
			fprintf (stdout, " file '%s' not found.\n", fn);
		    }
		} else if (c == 'p') {	// save picture
		    int h, v, fr, H, V, nf = 1;
		    while ((c = rx_data ()) != '\n') {
			str[i++] = c;
		    }
		    str[i] = '\0';
		    sscanf (str, "%d %d %d %s", &H, &V, &nf, fn);
		    if (*fn == '\0')
			strcpy (fn, "save.pgm");
		//  printf("**|%s|%s\n", str, fn);
		    printf (" save %d x %d x %d picture to %s\n", H, V, nf, fn);
		    if ((sfp = fopen (fn, "w")) != NULL) {
			fprintf (sfp, "P5 %d %d %d\n", H, V, 255);
			for(fr = 0; fr < nf; fr++){
			  for (v = 0; v < V; v++) {
			    for (h = 0; h < H; h++) {
				c = rx_data ();
				fputc (c, sfp);
			    }
			  }
			}
			if (sfp)
			    fclose (sfp);
			sfp = NULL;
		    } else {
			fprintf (stdout, " file '%s' can't open.\n", fn);
		    }
		} else {
		    if (dbg) {
			dump ('\033');
			dump (c);
		    } else {
			fputc ('\033', ofp);
			fputc (c, ofp);
		    }
		}
	    } else {
		if (cc == 0 && c == 'q') {
		    //      if(ofp != stderr) pclose(ofp);
		    ofp = stderr;
		}
		//      if(cc == 0 && c == 'w'){
		//              if(!pfp) pfp = popen("wplot/wplot", "w");
		//      }
		//      if(cc == 0 && (c == ':' || c == '$')){
		//              if(rpen && !pfp) pfp = popen("rplot/rplot", "w");
		//              if(pfp) rplot = 1;
		//      }
		//      if(rplot && pfp){
		//              fputc(c, pfp);
		//      }
		cc++;
		//      if(dbg)
		//              dump(c);
		//      else if(!rplot)

		fputc (c, ofp);

		if (c == '\n') {
		    //              if(pfp) fflush(pfp);
		    //              rplot = 0;
		    cc = 0;
		}
	    }
	    //      fflush(ofp);
	    fflush (NULL);
	}
	if (ufds[1].revents & POLLOUT) {
	    if (ifp) {
		if ((c = fgetc (ifp)) != EOF) {
		    tx_data (c);
		} else {
		    pclose (ifp);
		    ifp = NULL;
		    ufds[1].events = POLLIN;
		}
	    }
	    if (!XOFF) {	//txfifo empty
//		ufds[1].events = POLLIN;
	    }
	}
	if(ufds[1].revents & (POLLERR|POLLHUP|POLLNVAL)){
		printf(" POLLHUP %x\n", ufds[1].revents);
		break;
	}
//if(ufds[0].revents) fprintf(stderr, "ev0:%x\n", ufds[0].revents);
//if(ufds[1].revents) fprintf(stderr, "ev1:%x\n", ufds[1].revents);
    }
    close (uartfd);
    sleep(1);
    deinit_term();
    goto start;
    return 0;
}
