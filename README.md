# Z-Yuuka 2nd.i

Modification of the second release of the first 1.1-compatible supernull. This version extends compatibility to 1.0, 1.1a4, and 1.1b1.
Documentation for the supernull technique can be found in the Supernull folder.
The `rop` folder contains the files loaded and run by the supernull. While editing them can be done freely, please don't rename either this folder or the files within.

## Usage
If you want to use the supernull technique yourself, I recommend reading the documentation attached to this character.
However, the most straightforward way to start using it is just to grab the `Supernull.st` file and load it as the `st` file for your character.
This file includes the ROP chain, bootstrap, and loader, so it has everything that's needed to set up a supernull. It will load and execute the `boot*.bin` file from the character's `rop` subfolder (the file used depends on MUGEN version).
All you need to provide is your custom code in these files.
Note that this version MUST use `st` rather than `st0~9`. We opted for this as `st` is loaded before the indexed files.

## Differences from Z-Yuuka 2nd
* [loader] Now uses the `rop` subfolder (*for now*), not the character's root folder
* [loader] Now uses the built-in file-reading functions instead of KERNEL32's
* [loader] Now dynamically allocates memory for the bin file using `fseek>ftell` to obtain its filesize directly, instead of just assuming 4 kB
* [loader] Now keeps the bin file open if the return value from its code is non-zero
* [bin] Variable Expansion's relative range has been made stricter (in other words, conforming to a character's memory space)
* [bin] Variable Expansion now also can be used with fvar
* [bin] Variable Expansion can now be toggled off at any time by writing 0 to `var(5259492)`. To reenable, write any other value
* [bin] DisplayToClipboard and AppendToClipboard now accept all removed format specifiers for easier debugging (%n will still crash as it's obsolete)

## Credits
[Ziddia](https://ziddia.blog.fc2.com/) - Made the original [Z-Yuuka 2nd](https://github.com/ZiddiaMUGEN/Z-Yuuka-2nd), pioneer of the ROP exploit, etc.; I'm just piggybacking off of it (i technically also helped with some things here but sh)

[Warunoyari](https://mugen.sanso.moe) - Providing a method to identify path + load files from the character folder, as well as assisting with expanding the ROP method to be compatible with other versions.
