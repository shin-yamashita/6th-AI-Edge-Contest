
#
# crt0.S : RISC-V startup routine
#

#  .section .text.startup
  .section .vector
  .global _start, __errno
  .type   _start, @function

_start:
  # Initialize global pointer
.option push
.option norelax
1:auipc gp, %pcrel_hi(__global_pointer$)
  addi  gp, gp, %pcrel_lo(1b)
.option pop
  la      sp, __stack_top
  la      t0, _irq_handle
  csrw    mtvec, t0

  # Clear the bss segment
  la      a0, _edata
  la      a2, _end
  sub     a2, a2, a0
  li      a1, 0
  call    memset

  lw      a0, 0(sp)                  # a0 = argc
  addi    a1, sp, __SIZEOF_POINTER__ # a1 = argv
  li      a2, 0                      # a2 = envp = NULL
  call    main
#  call    init

  call    at_exit

  li      t0, 93	# SYS_exit
  scall

Loop:
  j    Loop

__errno:
  nop

  .section .text.startup

#// 0    1    2    3    4    5    6    7    8    9   10    11    12   13   14   15
#{"x0","ra","sp","gp","tp","t0","t1","t2","s0","s1","a0", "a1", "a2","a3","a4","a5",

  .align 4
_irq_handle:
    # Save registers.
    addi  sp, sp, -(12*4)
    sw    ra, (0*4)(sp)
    sw    a0, (1*4)(sp)
    sw    a1, (2*4)(sp)
    sw    a2, (3*4)(sp)
    sw    a3, (4*4)(sp)
    sw    a4, (5*4)(sp)
    sw    a5, (6*4)(sp)
    sw    s0, (7*4)(sp)
    sw    s1, (8*4)(sp)
    sw    t0, (9*4)(sp)
    sw    t1, (10*4)(sp)
    sw    t2, (11*4)(sp)

    # Invoke the handler.
    mv      a0, sp
    csrr    a1, mcause
    csrr    a2, mepc
    jal     irq_handler

    # Restore registers.
    lw    ra, (0*4)(sp)
    lw    a0, (1*4)(sp)
    lw    a1, (2*4)(sp)
    lw    a2, (3*4)(sp)
    lw    a3, (4*4)(sp)
    lw    a4, (5*4)(sp)
    lw    a5, (6*4)(sp)
    lw    s0, (7*4)(sp)
    lw    s1, (8*4)(sp)
    lw    t0, (9*4)(sp)
    lw    t1, (10*4)(sp)
    lw    t2, (11*4)(sp)
    addi  sp, sp, (12*4)
    

    # Return
    mret

