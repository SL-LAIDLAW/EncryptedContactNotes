--version 0.1
tell application "Contacts"
	set contactsSelection to selection
	if (count of selection) is equal to 1 then
		repeat with contactcard in contactsSelection
			set encrypted_note_original to note of contactcard
		end repeat
	end if
end tell

log encrypted_note_original

set contactNote_Empty to false
if encrypted_note_original is equal to missing value then set contactNote_Empty to true
if encrypted_note_original is equal to "" then set contactNote_Empty to true
set encrypted_note_original to "-----BEGIN PGP MESSAGE-----

" & encrypted_note_original & "
" & "-----END PGP MESSAGE-----"


-- Secure RAM setup
do shell script "diskutil partitionDisk $(hdiutil attach -nomount ram://20480) 1 GPTFormat APFS 'contactsramdisk' '100%'"
set ramdir to "/Volumes/contactsramdisk/"
set passphrase_file to POSIX file (ramdir & "passphrase.txt")
set oldmessage_file to POSIX file (ramdir & "oldmessage.asc")
set oldmessage_clear to POSIX file (ramdir & "oldmessage_clear.txt")
set newmessage_clear to POSIX file (ramdir & "newmessage_clear.txt")
set newmessage_file to POSIX file (ramdir & "newmessage_clear.txt.asc")



-- Get the passphrase and write to file on RAM drive
try
	set gpgsym_password to the text returned of (display dialog "Please enter a passphrase" default answer "" with icon stop buttons {"Cancel", "Continue"} default button "Continue" with hidden answer)
on error
	tell application "Finder"
		set diskName to "contactsramdisk"
		if disk diskName exists then
			eject disk diskName
			error "Operation Cancelled"
		end if
	end tell
end try


my write_to_file(gpgsym_password, passphrase_file, false)

if contactNote_Empty is not true then
	my write_to_file(encrypted_note_original, oldmessage_file, false)
	
	set decrypt_cmd to "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$PATH;gpg --batch --output " & (quoted form of POSIX path of oldmessage_clear) & " --passphrase-file " & (quoted form of POSIX path of passphrase_file) & " --decrypt " & (quoted form of POSIX path of oldmessage_file)
	
	try
		do shell script decrypt_cmd
	on error
		tell application "Finder"
			set diskName to "contactsramdisk"
			if disk diskName exists then
				eject disk diskName
				error "Wrong Encryption Key"
			end if
		end tell
	end try
	
	try
		set new_message_clear to the text returned of (display dialog "" default answer (read oldmessage_clear) buttons {"Cancel", "Continue"} default button "Continue")
	on error
		tell application "Finder"
			set diskName to "contactsramdisk"
			if disk diskName exists then
				eject disk diskName
				error "Cancelled"
			end if
		end tell
	end try
else
	try
		set new_message_clear to the text returned of (display dialog "" default answer (linefeed) buttons {"Cancel", "Continue"} default button "Continue")
	on error
		tell application "Finder"
			set diskName to "contactsramdisk"
			if disk diskName exists then
				eject disk diskName
				error "Cancelled"
			end if
		end tell
	end try
end if

if new_message_clear is not equal to oldmessage_clear then
	
	my write_to_file(new_message_clear, newmessage_clear, false)
	
	set encrypt_cmd to "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$PATH;gpg --batch --armor --symmetric --cipher-algo AES256 --passphrase-file " & (quoted form of POSIX path of passphrase_file) & " " & (quoted form of POSIX path of newmessage_clear) & " && rm " & (quoted form of POSIX path of newmessage_clear) & "; rm -f " & (quoted form of POSIX path of oldmessage_clear) & "; rm " & (quoted form of POSIX path of passphrase_file) & "; rm -f " & (quoted form of POSIX path of oldmessage_file)
	
	do shell script encrypt_cmd
	
	--set new_message_enc to (read newmessage_file)
	set new_message_enc to (do shell script "cat " & (quoted form of POSIX path of newmessage_file) & " | sed '/-----.*/d' | sed '/^$/d'")

	
	tell application "Contacts"
		set contactsSelection to selection
		if (count of selection) is equal to 1 then
			repeat with contactcard in contactsSelection
				set note of contactcard to new_message_enc
			end repeat
			save
		end if
	end tell
	
	do shell script "rm " & (quoted form of POSIX path of newmessage_file)
	
	
	-- test it correctly set
	tell application "Contacts"
		set contactsSelection to selection
		if (count of selection) is equal to 1 then
			repeat with contactcard in contactsSelection
				log (note of contactcard)
			end repeat
			save
		end if
	end tell
	

	
else
	log "identical"
end if

tell application "Finder"
	set diskName to "contactsramdisk"
	if disk diskName exists then
		eject disk diskName
	end if
end tell



on write_to_file(this_data, target_file, append_data) -- (string, file path as string, boolean)
	try
		set the target_file to the target_file as text
		set the open_target_file to Â
			open for access file target_file with write permission
		if append_data is false then Â
			set eof of the open_target_file to 0
		write this_data to the open_target_file starting at eof
		close access the open_target_file
		return true
	on error
		try
			close access file target_file
		end try
		return false
	end try
end write_to_file