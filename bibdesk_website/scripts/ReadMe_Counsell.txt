h1. Pages bibliography

This is a quick fix for bibliographies in the Apple Pages wordprocessor.  It works with BibTex bibliography files.  It is just proof of concept at the moment.  It only does author year type citations and produces the bibliography in a random order. 

h2. Versions

2005 Feb 2 - Version 0.0.1 - First public release.  Proof of concept only.

h2. Author

Pages-bibtex is (c) 2005 Thomas Counsell tamc2@cam.ac.uk. Please report bugs (there are many at the moment), suggestions and feedback to him.  Please also let him know if you wish to be notified of future versions.

It is GPL so feel free to edit and share.  

h2. Example

Open a terminal window.  Change into this directory.

1) open test.pages
2) ruby pages-bibtex.rb test.pages
3) open test-with-bibliography.pages 

h2. Usage

To create and manage BibTex bibliographies I recomend [[ BibDesk : http://bibdesk.sourceforge.net/ ]].

To cite a document, type \cite{key} in the text where key is the cite key defined in the BibTex file.  To cite the author use \citeauthor{key} to cite the year use \citeyear{key} to cite the author.

At the end of the document write \bibliography{bibfilename} where bibfilename is the filename of the bibtex file that has your citations.  This should NOT have the trailing .bib extension.

After that there should be a series of paragraphs like this:
<code>
BIBLIOGRAPHY-DEFAULT author. title (year).

BIBLIOGRAPHY-ARTICLE author. “title” journal volume.number (year):pages.

BIBLIOGRAPHY-BOOK author. title. address: publisher, year.

BIBLIOGRAPHY-PATENT author. Assigned to assignee. title. nationality patent number, year.
</code>
These define the style of the bibliography.  Any formatting applied to the words in this will be applied to citations in the final output.  Make sure you press return after defining the last of these.

To create the bibliography, run:
<code>
ruby pages-bibtex.rb filename.pages
</code>

This will create a copy of your pages document, with a bibliography, in filename-with-bibliography.pages.  This can then be opened in pages.

h2. WARNINGS / BUGS:

1) This is a first kludge.  I will improve it over time.
2) Opening the document-with-bibliography.pages WILL OFTEN CRASH PAGES. But if you restart pages it will normally then open.
3) Most of the bibliography may be missing until you trigger pages to re-format and re-display (e.g. by creating a new line or inserting some text).