# Bundled fonts

Literata and Source Sans 3 are distributed under the SIL Open Font License; see the accompanying `*-OFL.txt` files.

The italic companions were added for native rich-text formatting. They use the same families as the existing Roman variable fonts:

- `literata-italic.ttf`: https://raw.githubusercontent.com/google/fonts/main/ofl/literata/Literata-Italic%5Bopsz%2Cwght%5D.ttf
- `sourcesans3-italic.ttf`: https://raw.githubusercontent.com/google/fonts/main/ofl/sourcesans3/SourceSans3-Italic%5Bwght%5D.ttf

The application registers both styles at process startup. Formatting tests exercise the bundled families, rather than relying on a system fallback.
