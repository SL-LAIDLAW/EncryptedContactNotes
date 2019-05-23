# EncryptedContactNotes
Applescript to allow easy adding and editing of encrypted notes to the Apple Contacts.app, using gpg symmetric encryption (AES 256). If using the "save password for session" option, a GPG Key ID will need to be specified at the top of the script which will be used to encrypt the passphrase to be remembered.

## Setup
To download, simply git clone the repository into the scripts folder for Contacts.app:
```
git clone  https://github.com/seanlaidlaw/EncryptedContactNotes.git ~/Library/Application\ Scripts/com.apple.AddressBook/
```

To use the script, you first need a gpg key. If one does not already exist it can be made using:
```
# to generate the key
gpg --full-generate-key

# to view your generated keys
gpg --list-keys
```



The ID for the key can then be copied into the header of the applescript, in place of the '123456' you see below. 

```{applescript}
-- Version 0.3

-- ###  < Configuration  > ### ---
set GPGKeyID to "123456" -- if you chose to store password it'll be saved in RAM encrypted with this key ID

-- ###   </ Configuration >   ### ---




-- Get note from selected Contact
tell application "Contacts"
	set contactsSelection to selection
```

## Usage
Since OSX Mojave, running the script from the menu no longer works.
As such, the easiest thing to do is to map the running of the command to a keyboard shortcut.
I have for example, in my skhd config, mapped Alt-X to run the following shell command that runs the applescript
```
osascript ~/Library/Application\ Scripts/com.apple.AddressBook/Contact\ Encrypted\ Notes.applescript
```
