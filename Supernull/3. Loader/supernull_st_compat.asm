.intel_syntax noprefix
# Some constants
# Made these adjustable to make it easier to reference.
#   builtin function pointers (exist either in MUGEN or in a non-rebase DLL)
.set HDL_KERNEL32,0x10008044
.set F_PTR_GETPROCADDR,0x10006080
.set F_PTR_CLOSEHANDLE,0x10006010
.set F_PTR_MEMCPY,0x62E95140
.set F_PTR_CALLOC10,0x0049B1B8
.set F_PTR_CALLOC11,0x004DE1F8
#   loaded function pointers (obtained via GetProcAddress)
.set F_PTR_VPROTECT, 0x67BD0324
.set F_PTR_VALLOC, 0x67BD0328
.set F_PTR_FREAD, 0x67BD032C
.set F_PTR_FOPEN, 0x67BD0330
.set F_PTR_FCLOSE, 0x67BD0334
.set F_PTR_FSEEK, 0x67BD0338
.set F_PTR_FTELL, 0x67BD033C
.set F_PTR_VFREE, 0x67BD0340
#   pointers to allocated memory regions/storage locations
.set PTR_CODE,0x67BD0344
.set PTR_VERSION_FLAG,0x67BD0200
.set PTR_STRINGS,0x67BD0210

#########################################################################
# Setup:                                                               ##
# 1. Analyze File path and Append LoadFile.asm for current version.    ##
# 2. Get a VirtualAlloc function pointer to allocate space for         ##
#    the custom code.                                                  ##
# 3. Call VirtualAlloc to create section for custom code.              ##
# [PTR_CODE] = pointer to code                                         ##
# 4. Get a ReadFile function pointer to read the code                  ##
#    into memory.                                                      ##
# 5. Get a CreateFileA function pointer to open the file handle.       ##
#########################################################################

# zero out EAX and Move ESP to EBX
  xor eax,eax
  mov ebx,esp

# Version Differentiation between 1.1A/1.1B and 1.0
  cmp BYTE PTR [0x00511094],0x31  # 0x31 == 1.1
  jne .path10
  cmp BYTE PTR [0x005110a8],0x34 # 0x34 == 1.1a4
  je .store11a4
  mov BYTE PTR [PTR_VERSION_FLAG],0x02 # store version as 1.1b1
  jmp .path11

.store11a4:
  mov BYTE PTR [PTR_VERSION_FLAG],0x01 # store version as 1.1a4

# 1.1 steps to get char folder
.path11:
  sub ebx,0xffffff1c # +0xE4 = ptr to path on stack
  mov ebx,DWORD PTR [ebx] # follow pointer
  jmp .donepath

# 1.0 steps to get char folder with version flag
.path10:
  mov BYTE PTR [PTR_VERSION_FLAG],al # store version as 1.0
  sub ebx,0xfffffe10 # +1F0 = ptr to path on stack
  mov ebx,DWORD PTR [ebx] # follow pointer
  nop # alignment error avoidance

# Copy the string over to the strings area using memcpy
# this uses a fixed size 0x100, however in theory this can be longer.
# should be revisited... probably
.donepath:
  mov ah,0x01 # mov eax,0x100; note eax is still 0 from the above
  push eax
  push ebx # src
  push offset [PTR_STRINGS] # dest
  call DWORD PTR [F_PTR_MEMCPY]
  add esp,0x0c

# Set eax to Character After / in chars/
  mov eax,offset [PTR_STRINGS+0x06]
# Loop to Find / Byte
.charsloop:
  cmp BYTE PTR [eax],0x2f
  je .donecharsloop
  inc eax
  cmp eax,0x67bd02ac
  jle .charsloop

# Increase from / character and append file path prefix
.donecharsloop:
  inc eax
  mov DWORD PTR [eax],0x2f706f72 # "rop/boot?.bin"
  mov DWORD PTR [eax+0x04],0x746f6f62
  cmp BYTE PTR [PTR_VERSION_FLAG],0x01 # 1.1a4
  mov DWORD PTR [eax+0x08],0x69622e62 # assume 1.1b1 and bootb.bin
  mov WORD PTR [eax+0x0c],0x006e
  jb .load10 # 1.0
  ja .load11 # 1.1b1
  mov BYTE PTR [eax+0x08],0x61 # use boota.bin instead

.load11:
  mov eax,DWORD PTR [0x004de1ec]          # fopen
  mov edx,DWORD PTR [0x004de1e8]          # fclose
  mov DWORD PTR [F_PTR_FOPEN],eax         #
  mov DWORD PTR [F_PTR_FCLOSE],edx        #
  mov eax,DWORD PTR [0x004de010]          # VirtualFree
  mov edx,DWORD PTR [0x004de260]          # fread
  mov DWORD PTR [F_PTR_VFREE],eax         #
  mov DWORD PTR [F_PTR_FREAD],edx         #
  mov eax,DWORD PTR [0x004de194]          # fseek
  mov edx,DWORD PTR [0x004de198]          # ftell
  mov DWORD PTR [F_PTR_FSEEK],eax         #
  mov DWORD PTR [F_PTR_FTELL],edx         #
  jmp .doneprep

.load10:
  mov BYTE PTR [eax+0x08],0x30            # use boot0.bin instead
  mov eax,DWORD PTR [0x0049b168]          # fopen
  mov edx,DWORD PTR [0x0049b150]          # fclose
  mov DWORD PTR [F_PTR_FOPEN],eax         #
  mov DWORD PTR [F_PTR_FCLOSE],edx        #
  mov eax,DWORD PTR [0x0049b014]          # VirtualFree
  mov edx,DWORD PTR [0x0049b164]          # fread
  mov DWORD PTR [F_PTR_VFREE],eax         #
  mov DWORD PTR [F_PTR_FREAD],edx         #
  mov eax,DWORD PTR [0x0049b154]          # fseek
  mov edx,DWORD PTR [0x0049b158]          # ftell
  mov DWORD PTR [F_PTR_FSEEK],eax         #
  mov DWORD PTR [F_PTR_FTELL],edx         #

.doneprep:
# Load from the file chars/FILEPATH/rop/bootX.bin
# Using fopen to get a file stream since it's compatible with various other simpler file access functions than ReadFile
  xor eax,eax                             # Set eax to "rb"
  mov ax,0x6272                           #
  push eax                                # push "rb"
  push esp                                # push mode
  push offset [PTR_STRINGS]               # push filename
  call DWORD PTR [F_PTR_FOPEN]            # call fopen("chars/FILEPATH/rop/bootX.bin", "rb")
  add esp,0x0c                            # ok
  mov DWORD PTR [F_PTR_FOPEN],eax         # Store the file handle here for later cleanup

# Set up a VirtualAlloc function pointer - required for allocating memory
# this is done by invoking GetProcAddress (this function pointer exists in MUGEN) with the KERNEL32 module handle + a string for VirtualAlloc
  mov ebx,PTR_STRINGS                     # setting up VirtualAlloc string (we don't need the filename anymore)
  mov DWORD PTR [ebx],0x74726956          # Virt
  mov DWORD PTR [ebx+0x04],0x416C6175     # ualA
  mov DWORD PTR [ebx+0x08],0x636F6C6C     # lloc
  mov BYTE PTR [ebx+0x0C],0x00            # (NULL)
  push ebx                                # push lpProcName
  push DWORD PTR [HDL_KERNEL32]           # push hModule
  call DWORD PTR [F_PTR_GETPROCADDR]      # call GetProcAddress(KERNEL32.h, "VirtualAlloc")
  mov DWORD PTR [F_PTR_VALLOC],eax        # stored VirtualAlloc pointer

# Set up a VirtualProtect function pointer - required for later
# Same deal as above; some of the above we don't need to execute twice
  mov DWORD PTR [ebx+0x04],0x506C6175     # ualP
  mov DWORD PTR [ebx+0x08],0x65746F72     # rote
  mov DWORD PTR [ebx+0x0B],0x00746365     # ect(NULL)
  push ebx                                # push lpProcName
  push DWORD PTR [HDL_KERNEL32]           # push hModule
  call DWORD PTR [F_PTR_GETPROCADDR]      # call GetProcAddress(KERNEL32.h, "VirtualProtect")
  mov DWORD PTR [F_PTR_VPROTECT],eax      # stored VirtualProtect pointer

# Get filelength for VirtualAlloc through an fseek/ftell chain
# We'll reset this later
  push 0x02                               # push origin
  push 0x00                               # push offset
  push DWORD PTR [F_PTR_FOPEN]            # push stream
  call DWORD PTR [F_PTR_FSEEK]            # call fseek(BinFile, 0x00, SEEK_END)
  call DWORD PTR [F_PTR_FTELL]            # call ftell(BinFile)
  mov DWORD PTR [F_PTR_FTELL],eax         # Would be a good idea to hold onto this for reading later
  add esp,0x0c                            # we only have to repair it now

# Allocate memory with the correct file size for the code section
  xor ecx,ecx                             # prep ecx for flAllocationType
  push 0x40                               # push flProtect
  mov ch,0x10                             # set ecx to 0x1000
  push ecx                                # push flAllocationType
  push eax                                # push dwSize
  push 0x00                               # push lpAddress
  call DWORD PTR [F_PTR_VALLOC]           # call VirtualAlloc(NULL, BinFile.Size, MEM_COMMIT, PAGE_EXECUTE_READWRITE)
  mov DWORD PTR [PTR_CODE],eax            # store code section pointer (won't overwrite VirtualAlloc just in case)

# Reset the file index
  push 0x00                               # push origin
  push 0x00                               # push offset
  push DWORD PTR [F_PTR_FOPEN]            # push stream
  call DWORD PTR [F_PTR_FSEEK]            # call fseek(BinFile, 0x00, SEEK_SET)
  add esp,0x0c                            # ok

# Read the file and close its handle
  push DWORD PTR [F_PTR_FOPEN]            # push stream
  push DWORD PTR [F_PTR_FTELL]            # push count
  push 0x01                               # push size
  push DWORD PTR [PTR_CODE]               # push buffer
  call DWORD PTR [F_PTR_FREAD]            # call fread(CodeSection, 0x01, BinFile.Size, BinFile)
  add esp,0x0c                            # incomplete repair to close the handle with stream
  call DWORD PTR [F_PTR_FCLOSE]           # call fclose(BinFile)
  add esp,0x04                            # Finish repairing

# Actually execute the code in the bin file
  call DWORD PTR [PTR_CODE]               #
  test eax,eax                            # If the return value is zero, close the file; otherwise keep it open
  jnz .cleanup                            #
  xor eax,eax                             # Prep for dwFreeType
  mov ah,0x80                             # set to 0x8000
  push eax                                # push dwFreeType
  push 0x00                               # push dwSize
  push DWORD PTR [PTR_CODE]               # push lpAddress
  call DWORD PTR [F_PTR_VFREE]            # call VirtualFree(CodeSection, NULL, MEM_RELEASE)

.cleanup:
# cleanup from 0x67BD0200 to 0x67BD0340
# this was a stupid way to do it, so i actually used the repetition ops
  xor eax,eax                             # DWORD to store
  mov edi,0x67bd0340                      # Dest
  xor ecx,ecx                             # Count
  mov cl,0x50                             # Setting all of these
  rep stosd                               #

##########################################################################
# Finalization:                                                        ##
# For ST finalization is a bit more complex. It expects 0 in EDI,      ##
# character base address in ESI, proper ESP (obviously), and           ##
# a statedef data structure in EAX. Statedef data structure is         ##
# completely trashed by the supernull... however we can regenerate it  ##
# empty (just have correct size/ptrs) and the game will use it no      ##
# issues.                                                              ##
##########################################################################

# check version for return
  mov eax, DWORD PTR [esp]
  mov eax, DWORD PTR [eax]
  cmp eax,0x00436122
  je .mugen11b1
  jmp .mugen11a4

.mugen11b1:
  push 0x04
  push 0x01
  call DWORD PTR [F_PTR_CALLOC11] # need to alloc space for a pointer to comply with MUGEN datastructure (uses calloc)
  add esp,0x08 # pass over args
  mov ebp,eax # save ptr
  xor eax,eax
  sub eax,0xffffff64 # some annoying math required due to sequential 0x00 bytes
  push eax # push arg
  xor eax,eax
  inc eax # eax=1 (statedef count, irrelevant, just need the structure to exist)
  mov ebx,0x00466550 # function to alloc memory for the statedef structure
  call ebx
  add esp,0x04 # pass over args
  mov DWORD PTR [ebp],eax # save statedef structure in pointer alloc'd earlier
  mov eax,ebp # return data
  xor edi,edi   # required to continue processing properly
  pop esp       # restore proper esp
  mov esi,DWORD PTR [esp+0x04] # get old esi value (char base) loaded
  ret

.mugen11a4:
  cmp eax,0x00435bf2
  jne .mugen10 # assume 1.0 if neither other version are matched
  push 0x04
  push 0x01
  call DWORD PTR [F_PTR_CALLOC11] # need to alloc space for a pointer to comply with MUGEN datastructure (uses calloc)
  add esp,0x8 # pass over args
  mov ebp,eax # save ptr
  xor eax,eax
  sub eax,0xffffff64 # some annoying math required due to sequential 0x00 bytes
  push eax # push arg
  xor eax,eax
  inc eax # eax=1 (statedef count, irrelevant, just need the structure to exist)
  mov ebx,0x00466000 # function to alloc memory for the statedef structure
  call ebx
  add esp,0x04 # pass over args
  mov DWORD PTR [ebp],eax # save statedef structure in pointer alloc'd earlier
  mov eax,ebp # return data
  xor edi,edi   # required to continue processing properly
  pop esp       # restore proper esp
  mov esi,DWORD PTR [esp+0x04] # get old esi value (char base) loaded
  ret

.mugen10:
  xor ecx,ecx
  mov cx,0x0118
  add DWORD PTR [esp],ecx # 1.0-specific return addr correction
  push 0x04
  push 0x01
  call DWORD PTR [F_PTR_CALLOC10] # need to alloc space for a pointer to comply with MUGEN datastructure (uses calloc)
  add esp,0x08 # pass over args
  mov esi,eax # save ptr
  xor eax,eax
  sub eax,0xffffff68 # some annoying math required due to sequential 0x00 bytes
  push eax # push arg
  xor eax,eax
  inc eax # eax=1 (statedef count, irrelevant, just need the structure to exist)
  mov ebx,0x00402f10 # function to alloc memory for the statedef structure
  call ebx
  add esp,0x04 # pass over args
  mov DWORD PTR [esi],eax # save statedef structure in pointer alloc'd earlier
  mov eax,esi # return data
  xor esi,esi   # required to continue processing properly
  pop esp       # restore proper esp
  mov edi,DWORD PTR [esp+0x04] # get old esi value (char base) loaded
  ret




