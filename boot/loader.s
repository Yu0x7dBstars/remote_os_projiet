%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

;构建GDT及其内部的描述符
GDT_BASE:	dd 0x00000000	;第0个描述符不用
			dd 0x00000000

CODE_DESC:	dd 0x0000ffff
			dd DESC_CODE_HIGH4

DATA_DESC:	dd 0x0000ffff
			dd DESC_DATA_HIGH4

VIDEO_DESC:	dd 0x80000007	;段基址0~15是8000，limit是7*4k
			dd DESC_VIDEO_HIGH4
		
GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1

times 60 dq 0	;预留60个描述符的空位，四字

;total_mem_bytes用于保存内存容量，当前偏移文件头0x200位置
total_mem_bytes dd 0	;内存中位置为0x900+0x200=0xb00

SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0	;代码段为下标一的描述符，左移3位放到段寄存器后
												;应该会丢掉高位的0
SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0          

;gdt指针前两字节为gdt界限最大为2的16次方减一，后四字节为gdt起始地址
gdt_ptr	dw GDT_LIMIT	;更类似变量
		dd GDT_BASE	;仅地址标号
loadermsg db '2 loader in real.'
loader_start:
;-------------------------------------------
;INT0x10	功能号：0x13	功能描述：打印字符串
;-------------------------------------------
;AH 子功能号=13H 
;BH = 页码 
;BL = 属性(若AL=00H或01H) 
;CX=字符串长度 
;(DH､DL)=坐标(､行列) 
;ES:BP=字符串地址 
;AL=显示输出方式 
;  0—字符串中只含显示字符，其显示属性在BL中，显示后，光标位置不变 
;  1—字符串中只含显示字符，其显示属性在BL中，显示后，光标位置改变 
;  2—字符串中含显示字符和显示属性。显示后，光标位置不变 
;  3—字符串中含显示字符和显示属性。显示后，光标位置改变 
;无返回值 
	mov sp,LOADER_BASE_ADDR
	mov bp,loadermsg
	mov cx,17
	mov ax,0x1301	
	mov bx,0x001f	;页号为0，1f蓝底粉红字
	mov dx,0x1800
	int 0x10

;---------------- 准备进入保护模式 ----------------
;1打开A20
;2加载gdt
;3将cr0的pe位置为1

;---------------- 打开A20 ---------------
	in al,0x92
	or al,0000_0010
	out 0x92,al

;---------------- 加载gdt ---------------
	lgdt [gdt_ptr]

;---------------- cr0第0位置1 ---------------
	mov eax,cr0 
	or eax,0x00000001
	mov cr0,eax

	jmp dword SELECTOR_CODE:p_mode_start	;刷新流水线

[bits 32]
p_mode_start:
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP
	mov ax,SELECTOR_VIDEO
	mov gs,ax
	 
	mov byte [gs:160],'p'

	jmp $
