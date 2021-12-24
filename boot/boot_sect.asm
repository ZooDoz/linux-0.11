; https://sites.google.com/site/cauchyfool/nasm-manual#4p5
; 寄存器介绍 https://iowiki.com/assembly_programming/assembly_registers.html
;          https://www.pianshen.com/article/87162110026/
;   16位寄存器：`AX`、`BX`、`CX`、`DX`
;       高8位 H 和低8位 L：`AH`、`BH`、`CH`、`DH`、`AL`、`BL`、`CL`、`DL`
;       32位 & 64位：`EAX`、`EBX`、`ECX`、`EDX`、`RAX`、`RBX`、`RCX`、`RDX`
;   段寄存器：
;       `CS`、section .text 的地址
;       `DS`、section .data 的地址
;       `SS`、与 SP(偏移量) 相加 -> SS:SP 可找到当前栈顶地址
;       `ES`、常用于字符串操作的内存寻址基址，与变址寄存器 DI 共用
;       `FS`、`GS`
;   指针寄存器：`IP`、`SP`、`BP`
;   32位：`EIP`、`ESP`、`EBP`
;   变址寄存器：
;       `SI`、源变址寄存器 (Source Index),通常用于保存源操作数(字符串)的偏移量，与 DS 搭配使用(DS:SI)
;       `DI`、通常用于保存目的操作数(字符串)的偏移量，与 ES 搭配使用(ES:DI)
;   控制寄存器：`IP`、`FLAGS`
;
;   CF:进位标志位。在无符号运算时，记录了运算结果的最高有效位向更高位的进位值或从更高位借位，产生进位或借位时CF=1，否则CF=0；
;
;   PF:奇偶标志位。相关指令执行后结果所有bit中1的个数为偶数，那么PF=1，1的个数为奇数则PF=0；
;
;   AF:辅助进位标志位。运算过程中看最后四位，不论长度为多少。最后四位向前有进位或者借位，AF=1,否则AF=0;
;
;   ZF:零标志位。相关指令执行后结果为0那么ZF=1,结果不为0则ZF=0；
;
;   SF:符号标志位。相关指令执行后结果为负那么SF=1，结果非负数则SF=0；
;
;   TF:调试标志位。当TF=1时，处理器每次只执行一条指令，即单步执行;
;
;   IF:中断允许标志位。它用来控制8086是否允许接收外部中断请求。若IF=1，8086能响应外部中断，反之则屏蔽外部中断;
;
;   DF:方向标志位。在串处理指令中，每次操作后，如果DF=0，si、di递增，如果DF=1，si、di递减；注意此处DF的值是由程序员进行设定的 cld命令是将DF设置为0，std命令是将DF设置为1；
;
;   OF:溢出标志位。记录了有符号运算的结果是否发生了溢出，如果发生溢出OF=1,如果没有OF=0；

;   跳转指令
;   https://cloud.tencent.com/developer/article/1471250
;   int 0x13 中断介绍
;   https://blog.csdn.net/cherisegege/article/details/79835737
;   https://en.wikipedia.org/wiki/INT_13H




SYS_SIZE  equ 0x3000                    ; 0x30000 bytes = 196K
SETUP_LEN equ 4				            ; nr of setup-sectors
; **
; 物理地址=段地址×16+偏移地址。更常见的说法是段地址左移4位之后加上偏移地址。
; 这种寻址方式是——基址+偏移=物理地址在8086上的具体实现。
BOOT_SEG  equ 0x07c0			        ; 段地址,bios加载       0x07c00
INIT_SEG  equ 0x9000			        ; 段地址,move程序       0x90000
SETUP_SEG equ 0x9020			        ; setup starts here   0x90200
SYS_SEG   equ 0x1000			        ; system loaded at    0x10000 (65536).
END_SEG   equ SYS_SEG + SYS_SIZE		; 结束位置= 起始位置+size
; ROOT_DEV:	 0x000 - same type of floppy as boot.
;   		 0x301 - first partition on first drive etc
ROOT_DEV equ 0x306                      ; 第二个硬盘的第一个分区

section .text
global _start                       ; must be declared for using gcc
_start:                             ; tell linker entry byte kits
	mov	ax,BOOT_SEG                 ;
	mov	ds,ax                       ; 将bios加载位置放到ds中
	mov	ax,INIT_SEG                 ;
	mov	es,ax                       ; 将init位置放到es中
	sub	si,si                       ; 清零
    sub	di,di                       ; 清零
	mov	cx,256                      ; 放入256
	                                ; rep指令常和串传送指令搭配使用
                                    ; 功能：根据cx的值，重复执行后面的指令
	rep movsw                       ; 将ds:si复制到es:di位置
	jmp	go,INIT_SEG                 ; 复制完256*2 bytes，跳转到init_sge位置+go偏移开始执行
	                                ; cs=9000

go:	mov	ax,cs                       ; cs位置,此时cs=9000
	mov	ds,ax                       ; ds=cs位置
	mov	es,ax                       ; es=cs位置
; put stack at 0x9ff00.
; 栈向下生长,设置远大于512的位置
	mov	ss,ax                       ; ss=cs位置
	mov	sp,0xFF00		            ; arbitrary value >>512

; load the setup-sectors directly after the boot block.
; Note that 'es' is already set up.

load_setup:
     ; 功能02H
     ; 功能描述：读扇区
     ; 入口参数：AH＝02H
     ; AL＝扇区数
     ; CH＝柱面
     ; CL＝扇区
     ; DH＝磁头
     ; DL＝驱动器，00H~7FH：软盘；80H~0FFH：硬盘
     ; ES:BX＝缓冲区的地址
     ; 出口参数：CF＝0——操作成功，AH＝00H，AL＝传输的扇区数，否则，AH＝状态代码
    mov	dx,0x0000		            ; drive 0, head 0
    mov	cx,0x0002		            ; sector 2, track 0
    mov	bx,0x0200		            ; address = 512, in INIT_SEG  读取内容放置位置es:bx
    mov	ax,0x0200 + SETUP_LEN	    ; service 2, nr of sectors    0x0204 02读取数据，04读取4个扇区
    int	0x13			            ; read it
    jnc	ok_load_setup		        ; ok - continue 成功跳转到 ok_load_setup
    mov	dx,0x0000
    mov	ax,0x0000		            ; reset the diskette
    int	0x13                        ; 复位磁盘
    jmp	load_setup                  ; 重新读取

ok_load_setup:

; Get disk drive parameters, specifically nr of sectors/track
     ; 功能08H
     ; 功能描述：读取驱动器参数
     ; 入口参数：AH＝08H
     ; DL＝驱动器，00H~7FH：软盘；80H~0FFH：硬盘
     ; 出口参数：CF＝1——操作失败，AH＝状态代码
     ; BL＝01H — 360K
     ;   ＝02H — 1.2M
     ;   ＝03H — 720K
     ;   ＝04H — 1.44M
     ; CH＝柱面数的低8位
     ; CL的位7-6＝柱面数的高2位
     ; CL的位5-0＝扇区数
     ; DH＝磁头数
     ; DL＝驱动器数
     ; ES:DI＝磁盘驱动器参数表地址
     ; 一张1.44MB的3.5英寸软盘，一面有80个磁道，而硬盘上的磁道密度则远远大于此值，通常一面有成千上万个磁道。可以用扩展方法取
	mov	dl,0x00
	mov	ax,0x0800		; AH=8 is get drive parameters 获取磁盘驱动号，古老的技术
	int	0x13
	mov	ch,0x00         ; 清理CH中数据
	mov	cs:sectors,cx   ; 一面有80个磁道，所以7-6位为0。将cx数据复制到cs段的sectors位置中 cs:sectors,读取的是cl中的数据，即扇区数
	mov	ax,INIT_SEG     ;
	mov	es,ax           ; 复位到es到INIT_SEG

; Print some inane message
    ; 获取光标位置和形状	AH=03H	BX=页码	AX=0，CH=行扫描开始，CL=行扫描结束，DH=行，DL=列
	mov	ah,0x03		; read cursor pos
	xor	bh,bh       ; 按位逻辑异或，清0
	int	0x10        ; 触发0x10中断

    ; 写字符串（EGA+，最低PC AT ）	AH=13H	AL=写模式，BH=页码，BL=颜色，CX=字符串长度，DH=行，DL=列，ES:BP=字符串偏移量
	mov	cx,24           ;
	mov	bx,0x0007		; page 0, attribute 7 (normal)
	mov	bp,msg1
	mov	ax,0x1301		; write string, move cursor
	int	0x10

; ok, we've written the message, now
; we want to load the system (at 0x10000)

	mov	ax,SYS_SEG
	mov	es,ax		        ; segment of 0x010000 更新es位置到SYS_SEG
	call read_it            ; 读取数据
	call kill_motor         ; 关闭软驱

; After that we check which root-device to use. If the device is
; defined (!= 0), nothing is done and the given device is used.
; Otherwise, either /dev/PS0 (2,28) or /dev/at0 (2,8), depending
; on the number of sectors that the BIOS reports currently.

	mov	ax,cs:root_dev  ; 检查cs:root_dev位置
	cmp	ax,0
	jne	root_defined    ; 不为0，已经加载完毕，否则设置root_dev
    ; 取出驱动器参数CL。
    ; 如果sectors=15,则说明是1.2Mb的驱动器
    ; 如果sectors=18，则说明是, 1.44Mb软驱。因为是可引导的驱动器，所以肯定是A驱。
	mov	bx,cs:sectors
	mov	ax,0x0208		; /dev/ps0 - 1.2Mb
	cmp	bx,15
	je	root_defined
	mov	ax,0x021c		; /dev/PS0 - 1.44Mb
	cmp	bx,18
	je	root_defined
; 不匹配则死循环
undef_root:
	jmp undef_root
root_defined:
	mov	cs:root_dev,ax  ; 记录root驱动器

; after that (everyting loaded), we jump to
; the setup-routine loaded directly after
; the boot block:
    ; 跳转到加载程序位置执行
	jmp	0,SETUP_SEG

; This routine loads the system at address 0x10000, making sure
; no 64kB boundaries are crossed. We try to load it as fast as
; possible, loading whole tracks whenever we can.
;
; in:	es - starting address segment (normally 0x1000)
;
s_read:	dw 1 + SETUP_LEN	; sectors read of current track
head:	dw 0			    ; current head
track:	dw 0			    ; current track

read_it:
	mov ax,es               ; 读取es段的地址
	test ax,0x0fff          ; and运算，判断ax&0x0fff是否等于0,这里检查es段地址必须大于0x0fff
	; 将两个操作数进行按位AND,设结果是TEMP
	; SF = 将结果的最高位赋给SF标志位，例如结果最高位是1，SF就是1
    ; 看TEMP是不是0
    ; 如果TEMP是0，ZF位置1
    ; 如果TEMP不是0，ZF位置0

die:
    ; jne是汇编指令中的一个条件转移指令。当ZF=0，转至标号处执行
    ; 这里如果上面test结果temp不是0，则ZF=0，说明&不为0，则死循环
    jne die			    ; es must be at 64kB boundary
	xor bx,bx		    ; bx is starting address within segment
	                    ; 清0
 ;磁盘组成原理 https://blog.csdn.net/zhanglh046/article/details/115710477
 ;磁盘基本知识 https://cloud.tencent.com/developer/article/1129947
 ;磁盘有多组盘片
 ;platter：盘片
 ;head：磁头，每个盘片一般有上下两面，分别对应1个磁头，共2个磁头
 ;            wxy: 难道还存在有3个磁头的？
 ;track：磁道，是从盘片外圈往内圈编号0磁道，1磁道...，靠近主轴的同心圆用于停靠磁头，不存储数据
 ;            wxy: 其作用貌似就是用于划分的，即我就是分"圈圈"维度的分割符
 ;cylinder：柱面/磁柱，圆柱体被磁道划分后得到的就是一个个cylinder，一个磁盘具有cylinder数等同track的数量
 ;           wxy: 我的理解称为磁柱更合适，因为无论是从其英文的含义还是划分方式，都可以看做是一个空心的水桶，
 ;                   磁盘是多个水桶套水桶，当然水桶也是有厚度的，这就跟扇区有关系了，下面会说。
 ;                   另外，为了理解的方便往往称之为"圈"，即内外圈....
 ;sector：扇区， 每个磁道都被切分成很多扇形区域，每道的扇区数量相同。
 ;             wxy: 查了一些资料，sector即扇区确实是指每个磁柱的横截面上被切分的小区域，切分者是半径，
 ;                    所以这里其实还隐藏一个新的概念: 扇面， 顾名思义就是指横截面被半径切分得到的像蛋糕一样的一个"小面"，称为"扇面"
 ;                    track 和 扇面的结合就得到了 sector
 ;扇区的大小: 每一个扇区可存储的字节数据，一般为512B，扇区为数据存储的最小单元。
 ;                   之前，外圈的扇区面积比内圈的大，但是因为使用的磁物质密度不同，所以内外圈(即内外cylinder)上的扇区大小都相同。
 ;                   现在，内外圈已经采用相同密度物质来存储数据，但是内外圈扇区数量不同
 ;                              wxy: 内外圈大小不同，划分数量又不同，就表示有可能每个扇区大小相同
 ;这里用的是古老的磁盘读取技术，1.44M的盘磁道为80
 ;
 ;
 ;

rp_read:
	mov ax,es           ; 比较es段是否到了end_seg
	cmp ax,END_SEG		; have we loaded all yet?
	jb  ok1_read         ; JB   ;无符号小于则跳转
	ret
ok1_read:
	mov ax,cs:sectors   ; 取出扇区信息
	sub ax,s_read       ; 最大-减去已读扇区，ax=需要读的扇区index
	mov cx,ax           ; 将index放入cx
	; SHL是一个汇编指令，作用是逻辑左移指令，将目的操作数顺序左移1位或CL寄存器中指定的位数。左移一位时，操作数的最高位移入进位标志位CF，最低位补零。
	shl cx,9            ; 将未读扇区数*512
	add cx,bx           ; +bx 获取最新偏移量
	; JNC 如果进位位没有置位则跳转 进位标志＝0 别名 JNB，JAE
	jnc ok2_read        ; 没有进位则跳转到ok2_read
	je  ok2_read         ; 判断是否相等
	xor ax,ax
	sub ax,bx
	shr ax,9
ok2_read:
	call read_track     ; 读取track里的某一个扇区，经过int 0x13后ah=0x00,al=读取扇区数
	mov cx,ax           ; 缓存ax数据，读扇区数
	add ax,s_read       ; ax增加读取的扇区，计算是否需要切换磁头
	cmp ax,cs:sectors   ; 比较扇区数是否达到track的最大值
	jne ok3_read        ; 跳转继续读
	mov ax,1            ;
	sub ax,head         ; 1-当前磁头号，循环0，1
	jne ok4_read        ; 1-后不等于0则跳转，表示当前切换了磁头
	inc track           ; 增加磁道号
ok4_read:
	mov head,ax         ; 更新磁头号
	xor ax,ax           ; 清0，ax
ok3_read:
	mov s_read,ax       ; 更新s_read，ax里是已读取的扇区号
	shl cx,9            ; cx里是read_track读取的扇区数量，cx左移9
	add bx,cx           ; bx增加长度+read_track读取的扇区数量
	; JNC 如果进位位没有置位则跳转 进位标志＝0 别名 JNB，JAE
	jnc rp_read         ; 没有进位，则跳转继续读
	mov ax,es           ;
	add ax,0x1000       ;
	mov es,ax           ;将当前段向后0x1000
	xor bx,bx
	jmp rp_read

; 读当前磁道上指定开始扇区和需读扇区数的数据到es:bx开始处。
; al － 需读扇区数； es:bx － 缓冲区开始位置。
read_track:
    ; 保存旧寄存器数据现场
	push ax
	push bx
	push cx
	push dx
	 ; 读取磁盘数据
     ; 功能02H
     ; 功能描述：读扇区
     ; 入口参数：AH＝02H
     ; AL＝扇区数
     ; CH＝柱面
     ; CL＝扇区
     ; DH＝磁头
     ; DL＝驱动器，00H~7FH：软盘；80H~0FFH：硬盘
     ; ES:BX＝缓冲区的地址
     ; 出口参数：CF＝0——操作成功，AH＝00H，AL＝传输的扇区数，否则，AH＝状态代码
	mov dx,track    ; track在dl位置，dh清0
	mov cx,s_read   ; 已读扇区
	inc cx          ; 已读+1
	mov ch,dl       ; 使用dl，即track。柱面设置
	mov dx,head     ;
	mov dh,dl       ; 磁头设置
	mov dl,0        ; 驱动设置
	and dx,0x0100   ; 校验使用0x0100
	mov ah,2
	int 0x13
	jc bad_rt
	; 恢复旧寄存器现场
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; 执行驱动器复位操作（磁盘中断功能号0），再跳转到read_track处重试。
bad_rt:
    mov ax,0
	mov dx,0
	int 0x13
	pop dx
	pop cx
	pop bx
	pop ax
	jmp read_track

; 这里关闭软盘驱动，保证软驱状态可知
; This procedure turns off the floppy drive motor, so
; that we enter the kernel in a known state, and
; don't have to worry about it later.
;
; https://zh.wikipedia.org/wiki/%E8%BB%9F%E7%A2%9F%E6%8E%A7%E5%88%B6%E5%99%A8
; 软盘控制器有三个I/O端口，如下所示：
;   资料端口
;   主状态寄存器（MSR）
;   控制端口
; 前两个端口存在于软盘控制器芯片中，而控制端口则位于外部电路里。下面是三个端口的对应地址。
;   端口地址[hex]	端口名称	    所在位置	        端口类型
;   3F5	            资料寄存器	软盘控制器芯片	双向输出/输入
;   3F4	            主状态寄存器	软盘控制器芯片	输入
;   3F2	            数字控制端口	外部电路	        输出
kill_motor:
	push dx             ; 压栈
	mov dx,0x3f2        ; 定义软驱端口
	mov al,0            ; 关闭
	out dx,al           ; 写入数据
	pop dx              ; 出栈恢复
	ret                 ; 返回

sectors:
	dw 0

msg1:
	db 13,10
	db "Loading system ..."
	db 13,10,13,10

org 508                     ;// 表示下面语句从地址508(1FC)开始，所以root_dev
root_dev:
	dw ROOT_DEV
boot_flag:
	dw 0xAA55