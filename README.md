# enlac
_Pipeline for Digital Scholarly Editing of Apocryphal Literature_

integrating transcription checking; tokenisation & normalisation ([tpen2tei-ENLAC](https://github.com/seretan/tpen2tei/tree/xmlrich_tokenization)); collation ([CollateX](https://github.com/interedition/collatex)); analysis ([Stemmarest-ENLAC](https://github.com/seretan/tradition_repo/tree/IRSB) & [Stemmaweb-ENLAC](https://github.com/seretan/stemmaweb/tree/IRSB)); and [TEI Critical Apparatus](https://tei-c.org/release/doc/tei-p5-doc/en/html/TC.html) export for edition visualisation.

The manual steps are the transcription in TEI format and the variant analysis via graph annotation.

The pipeline will take you from your TEI transcriptions to variant graph editing in one command.

## Instructions
### Setup
- Install Git and clone this repository:

```
git clone https://github.com/unilenlac/enlac.git
cd enlac
```

- Install Docker Compose

### Running the pipeline
- Copy docker-compose.yml to the folder containing your XML transcriptions. You may use, for instance, the examples provided in `testdata/`:

```
    cp docker-compose.yml testdata/
```

- Then go to that folder:

```
cd testdata/
```

- And **run the command**:

```
docker-compose up
```

### Results
To begin editing, go to [http://localhost:3000/](http://localhost:3000/).
To see the files, browse the contents of the subfolder `out/`.
