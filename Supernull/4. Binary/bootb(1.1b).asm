.intel_syntax noprefix
##########################################################################
# Z-Yuuka Supernull (1.1b1-i)											##
# Variable Expansion, Display/AppendToClipboard "desanitization"		##
# This allows generalized memory editing via var access					##
# and easier debugging.													##
##########################################################################
# Some constants
.set HDL_KERNEL32,0x10008044
.set F_PTR_GETPROCADDR,0x10006080
.set F_PTR_GETMODULEHANDLE,0x004de04c
.set PTR_CODE,0x67bd0344
.set PTR_STRINGS,0x67bd0210

# 1. VirtualProtect the MUGEN code segment, fetch sprintf
ExecVP:											###################################
  mov ebp,DWORD PTR [PTR_CODE]					# Base location
  mov eax,DWORD PTR [0x67bd0324]				# VirtualProtect ptr
  push 0x67bd0348								# lpflOldProtect
  push 0x40										# flNewProtect
  push 0x000de000								# dwSize
  push 0x00400000								# lpAddress
  call eax										# call VirtualProtect(0x00400000, 0x000de000, PAGE_EXECUTE_READWRITE, lpflOldProtect)
  cmp DWORD PTR [0x00400300],0x00				# If this already contains code, skip
  mov DWORD PTR [0x005040e4],0x00000001 		# Variable Expansion Auto-Enable
  je Rewrite									# 
  xor eax,eax									# Close the file
  ret 											# 

# 2. Patch the var range checking code
#   This file contains the code, so I don't need to put the code manually in the engine (which is nice!)
Rewrite:										###################################
  mov DWORD PTR [0x00400300],0x00000001         # we exist!
  lea esi,[ebp+VarRead]							# Address of custom code
  sub esi,0x00456f58							# jmp offset (the end of the jmp instruction is at the instruction+5)
  mov ebx,0x00456f53							# address for instruction to modify
  mov BYTE PTR [ebx],0xe9 						# write 1
  mov DWORD PTR [ebx+0x01],esi					# write 2
  lea esi,[ebp+VarWrite]						# Address of custom code
  sub esi,0x00402e78							# jmp offset (the end of the jmp instruction is at the instruction+5)
  mov ebx,0x00402e73							# address for instruction to modify
  mov BYTE PTR [ebx],0xe9 						# write 1
  mov DWORD PTR [ebx+0x01],esi					# write 2
  lea esi,[ebp+FVarRead]						# Address of custom code
  sub esi,0x00456ff1							# jmp offset (the end of the jmp instruction is at the instruction+5)
  mov ebx,0x00456fec							# address for instruction to modify
  mov BYTE PTR [ebx],0xe9 						# write 1
  mov DWORD PTR [ebx+0x01],esi					# write 2
  lea esi,[ebp+FVarWrite]						# Address of custom code
  sub esi,0x00402ed6							# jmp offset (the end of the jmp instruction is at the instruction+5)
  mov ebx,0x00402ed1							# address for instruction to modify
  mov BYTE PTR [ebx],0xe9 						# write 1
  mov DWORD PTR [ebx+0x01],esi					# write 2

# 2. Patch DisplayToClipboard/AppendToClipboard
#   Again, this file contains the code, but it also contains a table containing pointers, which need adjustment
  add DWORD PTR [ebp+(FSpecIsWildcard.FetchType+0x03)],ebp # Self code adjustment
  add DWORD PTR [ebp+(FSpecIsWildcard.FetchType+0x0a)],ebp #
  add DWORD PTR [ebp+(FSpecIsShort.FetchType+0x02)],ebp #
  add DWORD PTR [ebp+(FSpecTypeLoc+0x10)],ebp 	# Pointer table adjustment
  add DWORD PTR [ebp+(FSpecTypeLoc+0x14)],ebp 	#
  add DWORD PTR [ebp+(FStrTypeLoc+0x10)],ebp 	# Pointer table adjustment
  add DWORD PTR [ebp+(FStrTypeLoc+0x14)],ebp 	#
  mov BYTE PTR [0x0045ae55],0x19            	# Tell the ".*" handler to execute the format specifier type check
  mov BYTE PTR [0x0045ae78],0x53 				# Allow 'x' to be the final char
  lea esi,[ebp+FSpecTypeMap]					# Format Specifier Pointer Map
  mov DWORD PTR [0x0045ae7e],esi				#
  lea edi,[ebp+FSpecTypeLoc]					# Format Specifier Pointer Table
  mov DWORD PTR [0x0045ae85],edi				#

# Everything else will be handled by the loader, so return
  mov eax,0x00000001							# Non-zero return value; keep file open
  ret 											# 

# 4. Actually tell the engine what to do
VarRead: 										###################################
  cmp DWORD PTR [0x005040e4],0x00 				# Standard read if zero
  jne VarRead.RawCheck							# 
  cmp DWORD PTR [esp+0x24],0x00 				# Default processing
  push 0x00456f58 								# Such that I don't have to adjust jmp addresses, use push/ret
  ret 											#
VarRead.RawCheck:								###########################
  cmp eax,0x0000055b 							# 0x156c/4 (1.1b1's playerwidth=0x2488)
  jnl VarRead.isRaw								# 
  cmp eax,0xfffffc39							# -0xf1c/4
  jl VarRead.isRaw								# 
  push 0x00456f47 								# Use default reading processing (but with a bigger range)
  ret 											#
VarRead.isRaw: 									###########################
  mov ebp,DWORD PTR [eax]						# 
  push 0x00458242 								# Return to standard trigger processing
  ret 											#
VarWrite: 										###################################
  cmp eax,0x005040e4							# You can always write here! If you couldn't, how would you re-enable this
  je VarWrite.isRaw 							# 
  cmp DWORD PTR [0x005040e4],0x00 				# Standard read if zero
  jne VarWrite.RawCheck							# 
  mov ecx,0x004f057c 							# Default processing
  push 0x00402e78 								# 
  ret 											#
VarWrite.RawCheck:								###########################
  cmp eax,0x0000055b 							# 0x156c/4
  jnl VarWrite.isRaw							# 
  cmp eax,0xfffffc39							# -0xf1c/4
  jl VarWrite.isRaw								# 
  push 0x00402e67 								# Use default writing processing (but with a bigger range)
  ret 											#
VarWrite.isRaw: 								###########################
  mov DWORD PTR [eax],esi						# 
  push 0x004034b6 								# Return to standard operator processing
  ret 											#
FVarRead: 										###################################
  cmp DWORD PTR [0x005040e4],0x00 				# Standard read if zero
  jne FVarRead.RawCheck							# 
  cmp DWORD PTR [esp+0x24],0x00 				# Default processing
  push 0x00456ff1 								# 
  ret 											#
FVarRead.RawCheck:								###########################
  cmp eax,0x0000051f 							# 0x156c/4-60
  jnl FVarRead.isRaw							# 
  cmp eax,0xfffffbfd							# -0xf1c/4-60
  jl FVarRead.isRaw								# 
  push 0x00456fdc 								# Use default reading processing (but with a bigger range)
  ret 											#
FVarRead.isRaw: 								###########################
  fld DWORD PTR [ebp+0x00]						#
  fstp DWORD PTR [esp+0x14]						#
  push 0x00458242 								# Return to standard trigger processing
  ret 											#
FVarWrite: 										###################################
  cmp DWORD PTR [0x005040e4],0x00 				# Standard read if zero
  jne FVarWrite.RawCheck						# 
  mov eax,DWORD PTR [ebp+0x08]              	# Default processing
  mov ecx,0x004f057c 							# 
  push 0x00402ed9 								# 
  ret 											#
FVarWrite.RawCheck:								###########################
  cmp eax,0x0000051f 							# 0x156c/4-60
  jnl FVarWrite.isRaw							# 
  cmp eax,0xfffffbfd							# -0xf1c/4-60
  jl FVarWrite.isRaw							# 
  push 0x00402ebe 								# Use default writing processing (but with a bigger range)
  ret 											#
FVarWrite.isRaw: 								###########################
  fld DWORD PTR [esp+0x40]						#
  mov ecx,DWORD PTR [ebp+0x08]					#
  fstp DWORD PTR [eax]							# 
  push 0x004034b6 								# Return to standard operator processing
  ret 											#
	
FSpecIsWildcard: 								###################################
  cmp BYTE PTR [esi+edi*1-0x01],0x2e 			# This is precision so who cares
  je FSpecIsWildcard.Continue 					#
  mov DWORD PTR [esp+0x0c],0x01             	# the width flag exists by technicality
  cmp BYTE PTR [esi+edi*1+0x01],0x2e 			# The next character is precision, though
  jne FSpecIsWildcard.Continue					#
  inc esi 										# Advance to the .
  push 0x0045ae47 								# go back
  ret 											#
FSpecIsWildcard.Continue:						###########################
  inc esi										# Well i sure hope this character is valid :)
  movsx eax,BYTE PTR [esi+edi*1]				#
  sub eax,0x41 									# Range of A to x
  cmp eax,0x37 									# 
  jna FSpecIsWildcard.FetchType					#
  push 0x0045aed0								# Invalid
  ret 											#
FSpecIsWildcard.FetchType:						###########################
  movzx eax,BYTE PTR [eax+(FSpecTypeMap+0x1c)]	# Fetch Type
  jmp DWORD PTR [eax*4+FSpecTypeLoc]			# Exactly like winmugen, ignore the fact that we need another argument :)
FSpecIsShort: 									###################################
  inc esi                                       # Next char
  movsx eax,BYTE PTR [esi+edi*1]				# 
  sub eax,0x58 									# Range of X to x
  cmp eax,0x20 									# 
  jna FSpecIsShort.FetchType					#
FSpecIsShort.Invalid:							###########################
  push 0x0045aed0								# Invalid
  ret 											#
FSpecIsShort.FetchType:							###########################
  cmp BYTE PTR [eax+(FSpecTypeMap+0x33)],0x02 	# Must explicitly be an int
  jne FSpecIsShort.Invalid						#
  push 0x0045ae89								# Return to int
  ret 											#

FSpecTypeMap:			 							###################################
  .byte 0x00,0x03,0x03,0x03,0x03,0x04,0x03,0x03 	# %&'()*+,
  .byte 0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03 	# -./01234
  .byte 0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03 	# 56789:;<
  .byte 0x03,0x03,0x03,0x03,0x01,0x03,0x03,0x03 	# =>?@ABCD
  .byte 0x01,0x01,0x01,0x03,0x03,0x03,0x03,0x03 	# EFGHIJKL
  .byte 0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03 	# MNOPQRST
  .byte 0x03,0x03,0x03,0x02,0x03,0x03,0x03,0x03 	# UVWXYZ[\
  .byte 0x03,0x03,0x03,0x03,0x01,0x03,0x06,0x02 	# ]^_`abcd
  .byte 0x01,0x01,0x01,0x05,0x02,0x03,0x03,0x03 	# efghijkl
  .byte 0x03,0x03,0x02,0x02,0x03,0x03,0x06,0x03 	# mnopqrst
  .byte 0x02,0x03,0x03,0x02 					 	# uvwx
FSpecTypeLoc:			 							###################################
  .int 0x0045aeaf									# Escaped %
  .int 0x0045ae9c									# float
  .int 0x0045ae89									# int
  .int 0x0045aed0									# invalid
  .int FSpecIsWildcard								# * handling
  .int FSpecIsShort 								# certain length sub-specifiers that decrease size (h>hh)
  .int 0x0045ae89 									# int (alt handler for %c, %s which are incompatible with h)