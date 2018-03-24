-- Version 0.3

-- ###  < Configuration  > ### ---
set GPGKeyID to "542591C2" -- if you chose to store password it'll be saved in RAM encrypted with this key ID

-- ###   </ Configuration >   ### ---




-- Get note from selected Contact
tell application "Contacts"
	set contactsSelection to selection
	if (count of selection) is equal to 1 then
		repeat with contactcard in contactsSelection
			set contact_note_initial to note of contactcard
		end repeat
	end if
end tell


-- Check if there is already a note there to either add or edit
set note_is_empty_bool to false
if contact_note_initial is equal to missing value then set note_is_empty_bool to true
if contact_note_initial is equal to "" then set note_is_empty_bool to true
set contact_note_initial to "-----BEGIN PGP MESSAGE-----

" & contact_note_initial & "
" & "-----END PGP MESSAGE-----"


-- RAM drive & files setup
do shell script "diskutil partitionDisk $(hdiutil attach -nomount ram://20480) 1 GPTFormat APFS 'contactsram_disk' '100%'"
set ram_disk to "/Volumes/contactsram_disk/"
set passphrase_file_clear to POSIX file (ram_disk & "passphrase.txt")
set contact_note_initial_file_encrypted to POSIX file (ram_disk & "oldmessage.asc")
set contact_note_initial_file_clear to POSIX file (ram_disk & "contact_note_initial_file_clear.txt")
set contact_note_modified_file_clear to POSIX file (ram_disk & "contact_note_modified_file_clear.txt")
set contact_note_modified_file_encrypted to POSIX file (ram_disk & "contact_note_modified_file_clear.txt.asc")
set passphrase_file_encrypted to POSIX file "/Volumes/temppasswordstore/password_store"
set password_store_enc to POSIX file "/Volumes/temppasswordstore/password_store.asc"

-- Ask to save password until editing is completed, only bother asking if password isn't already mounted though
set remember_password_bool to false
if not (do shell script "if [ -d /Volumes/temppasswordstore/ ]; then echo yes;else echo no; fi") as boolean then
	if (button returned of (display dialog "Remember password for this session?" buttons {"No, Enter it Manually", "Yes and Continue"} default button "Yes and Continue")) is equal to "Yes and Continue" then
		do shell script "diskutil partitionDisk $(hdiutil attach -nomount ram://20480) 1 GPTFormat APFS 'temppasswordstore' '100%'"
		set remember_password_bool to true
	end if
end if



-- Get the passphrase from file if its mounted, or by asking if not
try
	if not (do shell script "if [ -f /Volumes/temppasswordstore/password_store.asc ]; then echo yes;else echo no; fi") as boolean then
		set passphrase to the text returned of (display dialog "Please enter a passphrase" default answer "" with icon stop buttons {"Cancel", "Continue"} default button "Continue" with hidden answer)
	else
		set passphrase to (do shell script "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$PATH;gpg --output - -d " & (quoted form of POSIX path of password_store_enc))
	end if
on error
	tell application "Finder"
		set diskName to "contactsram_disk"
		if disk diskName exists then
			eject disk diskName
			error "Operation Cancelled"
		end if
	end tell
end try


-- Write the passphrase to file in clear on temp RAM drive, and encrypt it if it needs to be saved for the session
my write_to_file(passphrase, passphrase_file_clear, false)
if remember_password_bool is true then
	my write_to_file(passphrase, passphrase_file_encrypted, false)
	set encrypt_passphrase_cmd to "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$PATH;gpg -ae --output " & (quoted form of POSIX path of password_store_enc) & " -r " & GPGKeyID & " " & (quoted form of POSIX path of passphrase_file_encrypted) & " && rm " & (quoted form of POSIX path of passphrase_file_encrypted)
	do shell script encrypt_passphrase_cmd
end if


if note_is_empty_bool is not true then
	my write_to_file(contact_note_initial, contact_note_initial_file_encrypted, false)
	
	set decrypt_passphrase_cmd to "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$PATH;gpg --batch --output " & (quoted form of POSIX path of contact_note_initial_file_clear) & " --passphrase-file " & (quoted form of POSIX path of passphrase_file_clear) & " --decrypt " & (quoted form of POSIX path of contact_note_initial_file_encrypted)
	
	try
		do shell script decrypt_passphrase_cmd
	on error
		tell application "Finder"
			set diskName to "contactsram_disk"
			if disk diskName exists then
				eject disk diskName
				error "Wrong Encryption Key"
			end if
		end tell
	end try
	
	try
		-- Give prompt to change existing note for selected contact
		set contact_note_modified to the text returned of (display dialog "" default answer (read contact_note_initial_file_clear) buttons {"Cancel", "Continue"} default button "Continue")
	on error
		tell application "Finder"
			set diskName to "contactsram_disk"
			if disk diskName exists then
				eject disk diskName
				error "Cancelled"
			end if
		end tell
	end try
else
	try
		-- Give prompt to start a note for selected contact
		set contact_note_modified to the text returned of (display dialog "" default answer (linefeed) buttons {"Cancel", "Continue"} default button "Continue")
	on error
		tell application "Finder"
			set diskName to "contactsram_disk"
			if disk diskName exists then
				eject disk diskName
				error "Cancelled"
			end if
		end tell
	end try
end if


-- If note is changed, save it and encrypt it
if contact_note_modified is not equal to contact_note_initial_file_clear then
	my write_to_file(contact_note_modified, contact_note_modified_file_clear, false)
	set encrypt_modified_note_cmd to "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$PATH;gpg --batch --armor --symmetric --cipher-algo AES256 --passphrase-file " & (quoted form of POSIX path of passphrase_file_clear) & " " & (quoted form of POSIX path of contact_note_modified_file_clear) & " && rm " & (quoted form of POSIX path of contact_note_modified_file_clear) & "; rm -f " & (quoted form of POSIX path of contact_note_initial_file_clear) & "; rm " & (quoted form of POSIX path of passphrase_file_clear) & "; rm -f " & (quoted form of POSIX path of contact_note_initial_file_encrypted)
	do shell script encrypt_modified_note_cmd
	
	set contact_note_modified_encrypted to (do shell script "cat " & (quoted form of POSIX path of contact_note_modified_file_encrypted) & " | sed '/-----.*/d' | sed '/^$/d'")
	
	-- Add modified note to the contact
	tell application "Contacts"
		set contactsSelection to selection
		if (count of selection) is equal to 1 then
			repeat with contactcard in contactsSelection
				set note of contactcard to contact_note_modified_encrypted
			end repeat
			save
		end if
	end tell
	
	do shell script "rm " & (quoted form of POSIX path of contact_note_modified_file_encrypted)
	
	
end if


-- Eject our RAM disk (and thus delete its contents)
tell application "Finder"
	set diskName to "contactsram_disk"
	if disk diskName exists then
		eject disk diskName
	end if
end tell



-- Subroutines
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