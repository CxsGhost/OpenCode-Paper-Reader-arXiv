# LaTeX Paper Template

This directory is a cleaned reusable paper template based on the original layout.

## Files

- `main.tex`: main entry file
- `papertemplate.cls`: class file for layout and title box
- `sections/`: section placeholders
- `assets/logojd.png`: JD logo used in the title box
- `assets/plainnat.bst`: bibliography style
- `references.bib`: placeholder BibTeX file

## How to use

1. Edit `main.tex` to set the title, authors, affiliations, metadata, and abstract.
2. Replace the placeholder text in `sections/*.tex`.
3. Replace `assets/logojd.png` if you want to use a different JD logo asset.
4. Uncomment the bibliography lines in `main.tex` if you need references.

## Notes

- The template automatically uses `assets/logojd.pdf`, `assets/logojd.png`, or `assets/logojd.jpg` if present.
- Hyperlink colors are set to JD red.
- A LaTeX compiler is not available in this environment, so compilation was not verified locally.
