# CATITOR

CATITOR is an extremely UNIX, extremely portable, extremely extensible visual line editor, designed to fill the gap between not using an editor and being a sane person.

## Features
- Line editing
- Easier to exit than ViM
- No native scrolling. (If your file doesn't fit on screen, it's probably too long anyway)
- No adding lines, just pure editing.


## CATITOR in action
[![asciicast](https://asciinema.org/a/484069.svg)](https://asciinema.org/a/484069)

## Usage

- `e` : Edit (overwrite) the current line
- `v` : Visit (open) an existing file
- `s` : Save the current edits to the the currently visited file
- `q` : quit
- Navigation: arrow keys


## Feature Comparison

| Feature                  | The standard editor `ed` | CATITOR                  | ViM                                         |
| Easy to exit             | ?                        | Yes                      | No                                          |
| Opening files            | ?                        | Yes                      | Yes                                         |
| Saving Files             | ?                        | Yes                      | `:w` maybe `!`                              |
| Visual Mode              | Not by default           | Yes                      | Yes but weird                               |
| Adding Lines             | ?                        | No                       | Yes                                         |
| Line numbers by default  | ?                        | Yes                      | You wish                                    |
| RegEx editing            | ?                        | Somewhat limited         | `^([yY][eE][sS])?$`                         |
| Syntax Highlighting      | ?                        | You don't need it        | I don't know, vimrc is a language in itself |
| Convoluted configuration | ?                        | No configuration at all! | `/YES`                                      |
| The standard editor      | Yes                      | (Future: yes)            | Never                                       |



## UNIX philosophy
CATITOR adheres to true UNIX-philosophies. Even the name is a UNIX-like recursive acronym:

`Catitor As Text-editor Is Treason of Reason`

- In UNIX everything is a file. In CATITOR, every line is a file, to maximise the UNIX experience. 
- A tool should do one thing, and one thing well. CATITOR is a line editor and only allows editing a single line at a time. 
- The whole program depends on other UNIX-utilities. CATITOR itself doesn't do much, besides calling `cat` and `split`. 


## Portability 
CATITOR offers extreme portability. The only dependencies are standard UNIX-utilities like `bash`, `cat` and `split`. Simply deploy the shell-script, make it executable and start editing (not creating!).

## Extensibility
The whole editor is written in 374 lines of BASH, most of them being comments. 

It supports colors and interactive cursor movement through ANSI-escape codes and is easily extendable. For instance implementing syntax highlighting would only be a matter of writing a series of `sed` expressions to parse code and inject the corresponding ANSI-escape codes at the appropriate places in the source code.

A good development environment should help a programmer to reduce bugs. CATITOR achieves this by not allowing the user to add new lines of source, but only edit existing lines. The default edit is to delete the entire line, effectively removing any bugs that might be present in the line. 
CATITOR is an EDITOR not and ADDITOR. Adding new, potentially bug-ridden, LOC to your project is not possible with CATITOR. 


## How does it work? 
When a file is visited, the entire file is split into lines and saved as separate files in a temporary directory. 
When a line is edited, the corresponding temporary file is overwritten. 
When a visited file is saved, the temporary files are concatenated and written as a single file. 

