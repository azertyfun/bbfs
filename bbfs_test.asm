; bbfs_test.asm
; Test the BBFS file system

; Consele API that we need
; Write Char              0x1003  Char, MoveCursor        None            1.0
; Write String            0x1004  StringZ, NewLine        None            1.0
define WRITE_CHAR 0x1003
define WRITE_STRING 0x1004

define BUFFER_SIZE 0x100

; What's the BBOS bootloader magic number?
define BBOS_BOOTLOADER_MAGIC 0x55AA
define BBOS_BOOTLOADER_MAGIC_POSITION 511

.org 0

start:
    ; Save the drive number
    SET [drive_number], A
    
    ; Say we're opening a device
    SET PUSH, str_device_open
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Open the device
    SET PUSH, device ; Arg 1: device to construct
    SET PUSH, [drive_number] ; Arg 2: drive to work on
    JSR bbfs_device_open
    SET A, POP
    ADD SP, 1
    
    ; TODO: no error code is to be returned. We should maybe add one.
        
    ; Open up the disk as a volume
    SET PUSH, str_volume_open
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Do it
    SET PUSH, volume ; Arg 1: volume
    SET PUSH, device ; Arg 2: device
    JSR bbfs_volume_open
    SET A, POP
    ADD SP, 1
    
    SET Z, A
    SET X, volume
    SET Y, device
    
    ; It may be unformatted but otherwise should be OK.
    IFN A, BBFS_ERR_UNFORMATTED
        IFN A, BBFS_ERR_NONE
            SET PC, fail
            
    ; Say we're formatting
    SET PUSH, str_formatting
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Format the volume
    SET PUSH, volume
    JSR bbfs_volume_format
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
    
    ; Say we're looking for a free sector
    SET PUSH, str_find_free
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Find a free sector and keep it in A for debugging
    SET PUSH, volume
    JSR bbfs_volume_find_free_sector
    SET A, POP
    
    ; On floppies it should always be sector 4 (after the 4 reserved for boot and FS)
    ; On HDDs it can be C
    IFN A, 4
        IFN A, 0x000C
            SET PC, fail
        
    ; Say we're making a file
    SET PUSH, str_creating_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Make a file
    SET PUSH, file
    SET PUSH, volume
    JSR bbfs_file_create
    SET A, POP
    ADD SP, 1
    
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Say we're looking for a free sector
    SET PUSH, str_find_free
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Find a free sector and keep it in A for debugging
    SET PUSH, volume
    JSR bbfs_volume_find_free_sector
    SET A, POP
    
    ; It should always be sector 5 (after the 4 reserved for boot and FS and the
    ; 1 just taken) on floppies, and 0xD on HDDs.
    IFN A, 5
        IFN A, 0x000D
            SET PC, fail
       
    ; Say we're writing to the file
    SET PUSH, str_write_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Write to the file 100 times
    SET B, 100
write_loop:
    ; Write to the file
    SET PUSH, file
    SET PUSH, str_file_contents
    SET PUSH, 25
    JSR bbfs_file_write
    SET A, POP
    ADD SP, 2
    
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    SUB B, 1
    IFN B, 0
        SET PC, write_loop
        
    ; Say we're flushing to disk
    SET PUSH, str_flush
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
        
    ; Flush the file to disk
    SET PUSH, file
    JSR bbfs_file_flush
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
    
    ; Say we're going to open
    SET PUSH, str_open
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
        
    ; Get the sector the file started at
    SET A, file
    ADD A, BBFS_FILE_START_SECTOR
    SET A, [A]
    ; Open the file again to go back to the start
    SET PUSH, file
    SET PUSH, volume
    SET PUSH, A
    JSR bbfs_file_open
    SET A, POP
    ADD SP, 2
    
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Say we're going to reoopen
    SET PUSH, str_reopen
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
        
    ; Reopen it just for fun
    SET PUSH, file
    JSR bbfs_file_reopen
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
    
    ; Say we're going to read
    SET PUSH, str_read
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Read some data
    SET PUSH, file
    SET PUSH, buffer
    SET PUSH, BUFFER_SIZE
    JSR bbfs_file_read
    SET A, POP
    ADD SP, 2
    
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Write it out (until the first null)
    SET PUSH, buffer
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Say we're going to skip
    SET PUSH, str_skip
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Skip ahead
    SET PUSH, file
    SET PUSH, 513
    JSR bbfs_file_seek
    SET A, POP
    ADD SP, 1
    
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; The offset should now be 0x100 we read plus 1 we skipped, but in the next
    ; sector
    SET A, file
    ADD A, BBFS_FILE_OFFSET
    IFN [A], 257
        SET PC, fail
    ; Next sector should be 5 on a floppy and 0xD on an HDD
    SET A, file
    ADD A, BBFS_FILE_SECTOR
    IFN [A], 5
        IFN [A], 0x000D
            SET PC, fail
        
    ; Say we're going to truncate
    SET PUSH, str_truncate
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Truncate to this sector
    SET PUSH, file
    JSR bbfs_file_truncate
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Say we're writing to the file
    SET PUSH, str_write_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Write in some new data instead.
    SET PUSH, file
    SET PUSH, str_file_contents2
    SET PUSH, 15
    JSR bbfs_file_write
    SET A, POP
    ADD SP, 2
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Flush the file to disk
    SET PUSH, file
    JSR bbfs_file_flush
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Say we're deleting the file
    SET PUSH, str_delete_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Actually delete it
    SET PUSH, file
    JSR bbfs_file_delete
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Say we're making a directory
    SET PUSH, str_mkdir
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Create a directory
    SET PUSH, directory
    SET PUSH, volume
    JSR bbfs_directory_create
    SET A, POP
    ADD SP, 1
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Make a toy file
    
    ; Say we're making a file
    SET PUSH, str_creating_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Make a file
    SET PUSH, file
    SET PUSH, volume
    JSR bbfs_file_create
    SET A, POP
    ADD SP, 1
    
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Populate an entry for it in the directory
    SET [entry+BBFS_DIRENTRY_TYPE], BBFS_TYPE_FILE
    SET [entry+BBFS_DIRENTRY_SECTOR], [file+BBFS_FILE_START_SECTOR]
    
    ; Pack in a filename
    SET PUSH, str_filename ; Arg 1: string to pack
    SET PUSH, entry ; Arg 2: place to pack it
    ADD [SP], BBFS_DIRENTRY_NAME
    JSR bbfs_filename_pack
    ADD SP, 2
    
    ; Add the entry to the directory
    ; Say we're doing it
    SET PUSH, str_linking_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Do it
    SET PUSH, directory
    SET PUSH, entry
    JSR bbfs_directory_append
    SET A, POP
    ADD SP, 1
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Copy the running program into the file with a giant write call
    ; Announce it
    SET PUSH, str_saving_memory
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Make the write call
    SET PUSH, file
    SET PUSH, 0
    SET PUSH, program_end
    JSR bbfs_file_write
    SET A, POP
    ADD SP, 2
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; And flush
    SET PUSH, file
    JSR bbfs_file_flush
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
        
    ; Now read it back
    SET PUSH, str_reopen
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
        
    SET PUSH, file
    JSR bbfs_file_reopen
    SET A, POP
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Read until the end
    SET PUSH, str_read_all
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Display the number
    SET B, [file+BBFS_FILE_SECTOR]
    ADD B, 48
    SET PUSH, 0
    SET PUSH, B
    SET B, SP
    SET PUSH, B
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 4
    
    ; I will be the position in the program we are checking
    SET I, 0
    
read_loop:
    SET PUSH, file
    SET PUSH, 0xA000
    SET PUSH, 256
    JSR bbfs_file_read
    SET C, POP
    ADD SP, 2
    
    ; Display the number
    SET B, [file+BBFS_FILE_SECTOR]
    IFG B, 9
        ; Too big to be a number, make it hex
        ADD B, 7
    ADD B, 48 ; Value of '0'
    SET PUSH, 0
    SET PUSH, B
    SET B, SP
    SET PUSH, B
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 4
    
    ; See if we got the right stuff
    SET J, 0xA000
compare_loop:
    IFN [I], [J]
        SET PC, mismatch
    ADD I, 1
    ADD J, 1
    IFN J, 0xA100
        IFL I, program_end
            ; Keep checking until we run out of file or program
            SET PC, compare_loop
    SET PC, compared
mismatch:
    SET B, [I]
    SET C, [J]
    SET X, [file+BBFS_FILE_SECTOR]
    SET PC, fail

compared:
    
    ; Now see if we got an EOF or not
    IFE C, BBFS_ERR_NONE
        SET PC, read_loop
    
    IFN C, BBFS_ERR_EOF
        ; If we don't have a clean EOF, die.
        SET PC, fail
        
    ; Open the directory
    ; Announce it
    SET PUSH, str_opening_directory
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    ; Do it
    SET PUSH, directory ; Arg 1: directory
    SET PUSH, volume ; Arg 2: BBFS_VOLUME
    ; Arg 3: sector
    SET PUSH, [directory+BBFS_DIRECTORY_FILE+BBFS_FILE_START_SECTOR]
    JSR bbfs_directory_open
    SET A, POP
    ADD SP, 2
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Say we're listing the directory
    SET PUSH, str_listing_directory
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    ; Read entries out
dir_entry_loop:
    ; Read the next entry
    SET PUSH, directory
    SET PUSH, entry
    JSR bbfs_directory_next
    SET A, POP
    ADD SP, 1
    IFE A, BBFS_ERR_EOF
        ; If we have run out, stop looping
        SET PC, dir_entry_loop_done
    IFN A, BBFS_ERR_NONE
        ; On any other error, fail
        SET PC, fail
    
    SET PUSH, str_entry
    SET PUSH, 0 ; No newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Unpack the filename
    SET PUSH, filename ; Arg 1: unpacked filename
    SET PUSH, entry ; Arg 2: packed filename
    ADD [SP], BBFS_DIRENTRY_NAME
    JSR bbfs_filename_unpack
    ADD SP, 2
    
    ; Print the filename
    SET PUSH, filename
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Loop until EOF
    SET PC, dir_entry_loop
    
dir_entry_loop_done:

    SET PUSH, str_newline
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Now see if we have the bootloader code
    IFE [bootloader_code], 0
        SET PC, no_bootloader
        
    ; Say we're installing the bootloader
    SET PUSH, str_bootloader
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Install the bootloader
    ; First set its magic word
    SET [bootloader_code+BBOS_BOOTLOADER_MAGIC_POSITION], BBOS_BOOTLOADER_MAGIC
    
    ; Then make a raw BBOS call to stick it as the first sector of our drive
    SET PUSH, 0 ; Arg 1: sector
    SET PUSH, bootloader_code ; Arg 2: pointer
    SET PUSH, [drive_number] ; Arg 3: drive number
    SET A, WRITE_DRIVE_SECTOR
    INT BBOS_IRQ_MAGIC
    ADD SP, 3
        
no_bootloader:

    ; Add an extra entry to the directory
    ; Say we're doing it
    SET PUSH, str_linking_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Populate the entry again
    SET [entry+BBFS_DIRENTRY_TYPE], BBFS_TYPE_FILE
    SET [entry+BBFS_DIRENTRY_SECTOR], [file+BBFS_FILE_START_SECTOR]
    
    ; Pack in a filename
    SET PUSH, str_filename2 ; Arg 1: string to pack
    SET PUSH, entry ; Arg 2: place to pack it
    ADD [SP], BBFS_DIRENTRY_NAME
    JSR bbfs_filename_pack
    ADD SP, 2
    
    ; Put in the entry
    SET PUSH, directory
    SET PUSH, entry
    JSR bbfs_directory_append
    SET A, POP
    ADD SP, 1
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Now remove the old entry
    ; Say we're doing it
    SET PUSH, str_unlinking_file
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    ; Do it
    SET PUSH, directory ; Arg 1: BBFS_DIRECTORY to modify
    SET PUSH, 0 ; Arg 2: entry index to delete
    JSR bbfs_directory_remove
    SET A, POP
    ADD SP, 1
    IFN A, BBFS_ERR_NONE
        SET PC, fail
        
    ; Make sure we didn't make the stack go wonky
    IFN SP, 0
        SET PC, fail_stack

    ; Say we're done
    SET PUSH, str_done
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
halt:
    SET PC, halt
    
fail_stack:
    ; Say we broke the stack
    SET PUSH, str_fail_stack
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    SET PC, halt
    
fail:
    ; Say we failed generically
    SET PUSH, str_fail
    SET PUSH, 1 ; With newline
    SET A, WRITE_STRING
    INT BBOS_IRQ_MAGIC
    ADD SP, 2
    
    SET PC, halt
    
#include "bbfs.asm"

; Strings
str_device_open:
    .asciiz "Opening device..."
str_volume_open:
    .asciiz "Opening volume..."
str_formatting:
    .asciiz "Formatting..."
str_loading:
    .asciiz "Loading..."
str_saving:
    .asciiz "Saving..."
str_find_free:
    .asciiz "Find free sector..."
str_creating_file:
    .asciiz "Creating file..."
str_write_file:
    .asciiz "Writing to file..."
str_file_contents: 
    .asciiz "This goes into the file!"
str_flush:
    .asciiz "Flushing to disk..."
str_open:
    .asciiz "Opening file..."
str_reopen:
    .asciiz "Returning to start..."
str_read:
    .asciiz "Reading data..."
str_skip:
    .asciiz "Seeking ahead..."
str_truncate:
    .asciiz "Truncating..."
str_file_contents2: 
    .asciiz "NEWDATANEWDATA"
str_read_all:
    .asciiz "Reading whole file..."
str_delete_file:
    .asciiz "Deleting..."
str_mkdir:
    .asciiz "Creating directory..."
str_filename:
    .asciiz "IMG.BIN"
str_linking_file:
    .asciiz "Adding directory entry..."
str_saving_memory:
    .asciiz "Saving program image to disk..."
str_opening_directory:
    .asciiz "Opening directory..."
str_listing_directory:
    .asciiz "Listing directory..."
str_entry:
    .asciiz "Entry: "
str_newline:
    DAT 0
str_bootloader:
    .asciiz "Installing bootloader..."
str_filename2:
    .asciiz "BOOT.IMG"
str_unlinking_file:
    .asciiz "Removing directory entry..."
str_done:
    .asciiz "Done!"
str_fail:
    .asciiz "Failed!"
str_fail_stack:
    .asciiz "Stack error."

; Mark the end of the program data
program_end:

; Reserve space for the filesystem stuff
drive_number:
.reserve 1
device:
.reserve BBFS_DEVICE_SIZEOF
volume:
.reserve BBFS_VOLUME_SIZEOF
file:
.reserve BBFS_FILE_SIZEOF
buffer:
.reserve BUFFER_SIZE
directory:
.reserve BBFS_DIRECTORY_SIZEOF
entry:
.reserve BBFS_DIRENTRY_SIZEOF
filename:
.reserve BBFS_FILENAME_BUFSIZE

bootloader_code:
; Include the BBFS bootloader assembled code. On the final disk the bootloader
; code will still be sitting around in an unallocated sector
#include "bbfs_bootloader.asm"

