

HTMLFILES = $(subst .txt,.html, $(wildcard *.txt))

# comment out the next 2 lines to use within xcode:
#UNLOCALIZED_RESOURCES_FOLDER_PATH = 
#BUILD_ROOT = .

DEST = $(BUILD_ROOT)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/BibDesk\ Help

all: html

html: ${HTMLFILES} appleHelp.css ${DEST} ${DEST}/gfx/
	cp -f appleHelp.css ${DEST}/ ;\
	cp -f gfx/*.* ${DEST}/gfx/

%.html: %.txt appleHelp.css
	./Markdown.pl $< > ${DEST}/$@
