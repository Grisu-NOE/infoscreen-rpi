# this is the name of the output pdf
DOKUMENT = infoscreen-info

all: de

clean: 
	rm -f *.tex~
	rm -f *.tex.backup
	rm -f $(DOKUMENT).aux
	rm -f $(DOKUMENT).log
	rm -f $(DOKUMENT).out
	rm -f $(DOKUMENT).toc
	rm -f $(DOKUMENT).bbl
	rm -f $(DOKUMENT).blg
	rm -f $(DOKUMENT).lof
	rm -f $(DOKUMENT).bcf
	rm -f $(DOKUMENT).pdflatex.output
	rm -f $(DOKUMENT)-blx.bib
	rm -f $(DOKUMENT).run.xml
	rm -f *.aux
	rm -f depfile
	rm -f *.replaced
	rm -f *.table
	rm -f *.gnuplot

clean-all: clean
	rm -f $(DOKUMENT).pdf

de: $(DOKUMENT).pdf

force: clean-all de


$(DOKUMENT).aux: $(DOKUMENT).tex
	pdflatex $(DOKUMENT).tex

$(DOKUMENT).bbl: $(DOKUMENT).aux
	biber $(DOKUMENT)

$(DOKUMENT).pdf: $(DOKUMENT).tex $(DOKUMENT).bbl
	pdflatex $(DOKUMENT).tex | tee $(DOKUMENT).pdflatex.output
	grep "Rerun to get cross-references right." $(DOKUMENT).pdflatex.output && pdflatex $(DOKUMENT).tex
	rm -f $(DOKUMENT).pdflatex.output

# end
