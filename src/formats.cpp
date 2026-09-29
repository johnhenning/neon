#include "formats.h"
#include "store.h"
#include <QAbstractTextDocumentLayout>
#include <QBuffer>
#include <QDateTime>
#include <QDir>
#include <QPainter>
#include <QPdfWriter>
#include <QRegularExpression>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextFragment>
#include <QUuid>
#include <QXmlStreamReader>
#include <QtEndian>
#include <zlib.h>
namespace neon {
namespace {
QString esc(const QString& s) {
    return s.toHtmlEscaped();
}
void u16(QByteArray& b, quint16 n) {
    b.append(static_cast<char>(n));
    b.append(static_cast<char>(n >> 8));
}
void u32(QByteArray& b, quint32 n) {
    u16(b, n & 65535);
    u16(b, n >> 16);
}
quint16 r16(const QByteArray& b, qsizetype p) {
    if (p < 0 || p + 2 > b.size())
        throw Error("Truncated ZIP archive");
    return qFromLittleEndian<quint16>(b.constData() + p);
}
quint32 r32(const QByteArray& b, qsizetype p) {
    if (p < 0 || p + 4 > b.size())
        throw Error("Truncated ZIP archive");
    return qFromLittleEndian<quint32>(b.constData() + p);
}
QString xhtml(const QString& html) {
    QTextDocument d;
    d.setHtml(html);
    QString out;
    for (auto block = d.begin(); block.isValid(); block = block.next()) {
        QString p;
        for (auto i = block.begin(); !i.atEnd(); ++i) {
            auto f = i.fragment();
            if (!f.isValid())
                continue;
            auto t = esc(f.text());
            auto fmt = f.charFormat();
            if (fmt.fontItalic())
                t = "<em>" + t + "</em>";
            if (fmt.fontWeight() >= QFont::Bold)
                t = "<strong>" + t + "</strong>";
            p += t;
        }
        out += "<p>" + p + "</p>\n";
    }
    return out;
}
QString wordParagraph(const QString& text, bool heading = false) {
    return "<w:p>" + QString(heading ? "<w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr>" : "") +
           "<w:r><w:t xml:space=\"preserve\">" + esc(text) + "</w:t></w:r></w:p>";
}
QString wordBody(const QString& html) {
    QTextDocument d;
    d.setHtml(html);
    QString out;
    for (auto b = d.begin(); b.isValid(); b = b.next()) {
        out += "<w:p>";
        for (auto it = b.begin(); !it.atEnd(); ++it) {
            auto f = it.fragment();
            if (!f.isValid())
                continue;
            out += "<w:r><w:rPr>";
            if (f.charFormat().fontItalic())
                out += "<w:i/>";
            if (f.charFormat().fontWeight() >= QFont::Bold)
                out += "<w:b/>";
            out += "</w:rPr><w:t xml:space=\"preserve\">" + esc(f.text()) + "</w:t></w:r>";
        }
        out += "</w:p>";
    }
    return out;
}
} // namespace
QString Formats::plain(const QString& h) {
    QTextDocument d;
    d.setHtml(h);
    return d.toPlainText();
}
int Formats::words(const QString& h) {
    static const QRegularExpression re(
        QStringLiteral("[\\p{L}\\p{N}]+(?:[’'\\-][\\p{L}\\p{N}]+)*"));
    auto it = re.globalMatch(plain(h));
    int n = 0;
    while (it.hasNext()) {
        it.next();
        ++n;
    }
    return n;
}
QString Formats::html(const Manuscript& b) {
    QString s = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>" + esc(b.title) +
                "</title><style>body{max-width:42em;margin:4em auto;font:12pt "
                "Georgia,serif;line-height:1.7}h1,h2{text-align:center}h2{page-break-before:always}"
                "p{text-indent:1.5em}</style></head><body><h1>" +
                esc(b.title) + "</h1><p>" + esc(b.subtitle) + "</p><p>" + esc(b.author) + "</p>";
    for (const auto& c : b.chapters)
        s += "<h2>" + esc(c.title) + "</h2>" + xhtml(c.html);
    return s + "</body></html>";
}
QByteArray Formats::zip(const QMap<QString, QByteArray>& entries) {
    QByteArray out, central;
    quint16 count = 0;
    // EPUB requires its uncompressed mimetype as the first entry.
    auto keys = entries.keys();
    if (keys.removeOne("mimetype"))
        keys.prepend("mimetype");
    for (const auto& key : keys) {
        auto n = key.toUtf8();
        auto data = entries[key];
        auto crc =
            quint32(crc32(0, reinterpret_cast<const Bytef*>(data.constData()), uInt(data.size())));
        auto offset = quint32(out.size());
        u32(out, 0x04034b50);
        u16(out, 20);
        u16(out, 0x800);
        u16(out, 0);
        u16(out, 0);
        u16(out, 0x21);
        u32(out, crc);
        u32(out, quint32(data.size()));
        u32(out, quint32(data.size()));
        u16(out, quint16(n.size()));
        u16(out, 0);
        out += n;
        out += data;
        u32(central, 0x02014b50);
        u16(central, 20);
        u16(central, 20);
        u16(central, 0x800);
        u16(central, 0);
        u16(central, 0);
        u16(central, 0x21);
        u32(central, crc);
        u32(central, quint32(data.size()));
        u32(central, quint32(data.size()));
        u16(central, quint16(n.size()));
        u16(central, 0);
        u16(central, 0);
        u16(central, 0);
        u16(central, 0);
        u32(central, 0);
        u32(central, offset);
        central += n;
        ++count;
    }
    auto offset = out.size();
    out += central;
    u32(out, 0x06054b50);
    u16(out, 0);
    u16(out, 0);
    u16(out, count);
    u16(out, count);
    u32(out, quint32(central.size()));
    u32(out, quint32(offset));
    u16(out, 0);
    return out;
}
QMap<QString, QByteArray> Formats::unzip(const QByteArray& b) {
    auto e = b.lastIndexOf(QByteArray::fromHex("504b0506"));
    if (e < 0 || e + 22 > b.size())
        throw Error("Not a supported ZIP archive");
    if (r16(b, e + 4) || r16(b, e + 6))
        throw Error("Multi-disk ZIP is unsupported");
    auto count = r16(b, e + 10);
    qsizetype p = r32(b, e + 16), total = 0;
    QMap<QString, QByteArray> out;
    for (int i = 0; i < count; ++i) {
        if (r32(b, p) != 0x02014b50)
            throw Error("Invalid ZIP directory");
        auto flags = r16(b, p + 8), method = r16(b, p + 10);
        auto crc = r32(b, p + 16), packed = r32(b, p + 20), size = r32(b, p + 24);
        auto nl = r16(b, p + 28), xl = r16(b, p + 30), cl = r16(b, p + 32);
        auto loc = r32(b, p + 42);
        if (p + 46 + nl + xl + cl > b.size() || size > 64 * 1024 * 1024 ||
            total + size > 256 * 1024 * 1024)
            throw Error("Archive exceeds safety limits");
        QString name = QString::fromUtf8(b.mid(p + 46, nl));
        p += 46 + nl + xl + cl;
        if (name.endsWith('/'))
            continue;
        for (const auto& part : name.split('/'))
            Store::safeId(part);
        if (QDir::isAbsolutePath(name) || out.contains(name) || (flags & 1))
            throw Error("Unsafe or encrypted archive entry");
        if (r32(b, loc) != 0x04034b50)
            throw Error("Invalid ZIP entry");
        qsizetype start = loc + 30 + r16(b, loc + 26) + r16(b, loc + 28);
        if (start + packed > b.size())
            throw Error("Truncated ZIP payload");
        QByteArray data;
        if (method == 0) {
            if (size != packed)
                throw Error("Invalid ZIP size");
            data = b.mid(start, packed);
        } else if (method == 8) {
            data.resize(size);
            z_stream z{};
            z.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(b.constData() + start));
            z.avail_in = packed;
            z.next_out = reinterpret_cast<Bytef*>(data.data());
            z.avail_out = size;
            if (inflateInit2(&z, -MAX_WBITS) != Z_OK)
                throw Error("Cannot initialize decompressor");
            auto result = inflate(&z, Z_FINISH);
            inflateEnd(&z);
            if (result != Z_STREAM_END || z.total_out != size)
                throw Error("Invalid compressed data");
        } else
            throw Error("Unsupported ZIP compression");
        if (quint32(crc32(0, reinterpret_cast<const Bytef*>(data.constData()),
                          uInt(data.size()))) != crc)
            throw Error("Archive checksum mismatch");
        total += size;
        out.insert(name, data);
    }
    return out;
}
QByteArray Formats::exportData(const Manuscript& b, const QString& format) {
    if (format == "html")
        return html(b).toUtf8();
    if (format == "txt" || format == "md") {
        QString s = (format == "md" ? "# " : "") + b.title + "\n\n" + b.author + "\n\n";
        for (const auto& c : b.chapters) {
            s += (format == "md" ? "## " : "") + c.title + "\n\n";
            QTextDocument d;
            d.setHtml(c.html);
            s += (format == "md" ? d.toMarkdown() : d.toPlainText()) + "\n\n";
        }
        return s.toUtf8();
    }
    if (format == "docx") {
        QMap<QString, QByteArray> z;
        z["[Content_Types].xml"] =
            R"(<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>)";
        z["_rels/.rels"] =
            R"(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>)";
        z["word/_rels/document.xml.rels"] =
            R"(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>)";
        z["word/styles.xml"] =
            R"(<?xml version="1.0"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/><w:sz w:val="24"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:pPr><w:pageBreakBefore/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style></w:styles>)";
        QString xml =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document "
            "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>" +
            wordParagraph(b.title) + wordParagraph(b.author);
        for (const auto& c : b.chapters)
            xml += wordParagraph(c.title, true) + wordBody(c.html);
        xml +=
            "<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1440\" "
            "w:bottom=\"1440\" w:left=\"1440\" w:right=\"1440\"/></w:sectPr></w:body></w:document>";
        z["word/document.xml"] = xml.toUtf8();
        return zip(z);
    }
    if (format == "epub") {
        QMap<QString, QByteArray> z;
        z["mimetype"] = "application/epub+zip";
        z["META-INF/container.xml"] =
            R"(<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>)";
        QString items = "<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" "
                        "properties=\"nav\"/>",
                spine, nav;
        int i = 0;
        for (const auto& c : b.chapters) {
            QString id = "ch" + QString::number(++i), file = id + ".xhtml";
            z["OEBPS/" + file] = ("<?xml version=\"1.0\" encoding=\"UTF-8\"?><html "
                                  "xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>" +
                                  esc(c.title) + "</title></head><body><h1>" + esc(c.title) +
                                  "</h1>" + xhtml(c.html) + "</body></html>")
                                     .toUtf8();
            items += "<item id=\"" + id + "\" href=\"" + file +
                     "\" media-type=\"application/xhtml+xml\"/>";
            spine += "<itemref idref=\"" + id + "\"/>";
            nav += "<li><a href=\"" + file + "\">" + esc(c.title) + "</a></li>";
        }
        z["OEBPS/nav.xhtml"] =
            ("<?xml version=\"1.0\"?><html xmlns=\"http://www.w3.org/1999/xhtml\" "
             "xmlns:epub=\"http://www.idpf.org/2007/ops\"><head><title>Contents</title></"
             "head><body><nav epub:type=\"toc\"><h1>Contents</h1><ol>" +
             nav + "</ol></nav></body></html>")
                .toUtf8();
        z["OEBPS/content.opf"] =
            ("<?xml version=\"1.0\"?><package xmlns=\"http://www.idpf.org/2007/opf\" "
             "version=\"3.0\" unique-identifier=\"bookid\"><metadata "
             "xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:identifier "
             "id=\"bookid\">urn:uuid:" +
             QUuid::createUuid().toString(QUuid::WithoutBraces) + "</dc:identifier><dc:title>" +
             esc(b.title) + "</dc:title><dc:creator>" + esc(b.author) +
             "</dc:creator><dc:language>en</dc:language><meta property=\"dcterms:modified\">" +
             QDateTime::currentDateTimeUtc().toString("yyyy-MM-ddTHH:mm:ssZ") +
             "</meta></metadata><manifest>" + items + "</manifest><spine>" + spine +
             "</spine></package>")
                .toUtf8();
        return zip(z);
    }
    throw Error("Unsupported export format");
}
Manuscript Formats::importData(const QByteArray& bytes, const QString& format,
                               const QString& title) {
    Manuscript book{title, "", "", {}};
    QString source = QString::fromUtf8(bytes);
    QList<Chapter> blocks;
    if (format == "docx") {
        auto entries = unzip(bytes);
        if (!entries.contains("word/document.xml"))
            throw Error("DOCX has no document.xml");
        QXmlStreamReader xml(entries["word/document.xml"]);
        QString p, run;
        bool bold = false, italic = false, heading = false;
        Chapter ch{"Chapter 1", ""};
        while (!xml.atEnd()) {
            xml.readNext();
            auto n = xml.name();
            if (xml.isStartElement()) {
                if (n == "p") {
                    p.clear();
                    heading = false;
                } else if (n == "r") {
                    run.clear();
                    bold = italic = false;
                } else if (n == "pStyle") {
                    for (const auto& a : xml.attributes())
                        if (a.name() == "val" &&
                            a.value().toString().startsWith("Heading", Qt::CaseInsensitive))
                            heading = true;
                } else if (n == "b")
                    bold = true;
                else if (n == "i")
                    italic = true;
                else if (n == "t")
                    run += esc(xml.readElementText());
                else if (n == "br")
                    run += "<br/>";
                else if (n == "tab")
                    run += "&#9;";
            } else if (xml.isEndElement()) {
                if (n == "r") {
                    if (bold)
                        run = "<b>" + run + "</b>";
                    if (italic)
                        run = "<i>" + run + "</i>";
                    p += run;
                } else if (n == "p") {
                    if (heading) {
                        if (!ch.html.trimmed().isEmpty())
                            book.chapters << ch;
                        ch = {plain(p), ""};
                    } else
                        ch.html += "<p>" + p + "</p>";
                }
            }
        }
        if (xml.hasError())
            throw Error("Malformed DOCX XML");
        if (!ch.html.isEmpty())
            book.chapters << ch;
    } else if (format == "txt" || format == "md") {
        Chapter ch{"Chapter 1", ""};
        QStringList pending;
        auto flush = [&] {
            if (pending.isEmpty())
                return;
            QString s = pending.join('\n');
            QTextDocument d;
            if (format == "md")
                d.setMarkdown(s);
            else
                d.setPlainText(s);
            ch.html += xhtml(d.toHtml());
            pending.clear();
        };
        QRegularExpression header("^(?:#{1,2}\\s+|(?:chapter|part)\\s+)(.+)$",
                                  QRegularExpression::CaseInsensitiveOption);
        for (const auto& line : source.split('\n')) {
            auto m = header.match(line.trimmed());
            if (m.hasMatch()) {
                flush();
                if (!ch.html.isEmpty())
                    book.chapters << ch;
                ch = {m.captured(1), ""};
            } else
                pending << line;
        }
        flush();
        if (!ch.html.isEmpty())
            book.chapters << ch;
    } else
        throw Error("Supported imports: DOCX, TXT, Markdown");
    if (book.chapters.isEmpty())
        book.chapters << Chapter{"Chapter 1", "<p></p>"};
    return book;
}
bool Formats::pdf(const Manuscript& b, const QString& path) {
    QPdfWriter writer(path);
    writer.setTitle(b.title);
    writer.setCreator("Neon");
    writer.setResolution(96);
    writer.setPageSize(QPageSize(QPageSize::A4));
    writer.setPageMargins(QMarginsF(20, 20, 20, 20));
    QTextDocument d;
    d.setHtml(html(b));
    d.setPageSize(QSizeF(writer.width(), writer.height()));
    QPainter p(&writer);
    if (!p.isActive())
        return false;
    int pages = d.pageCount();
    for (int i = 0; i < pages; ++i) {
        if (i && !writer.newPage())
            return false;
        p.save();
        p.setClipRect(QRectF(0, 0, writer.width(), writer.height()));
        p.translate(0, -i * writer.height());
        QAbstractTextDocumentLayout::PaintContext ctx;
        ctx.clip = QRectF(0, i * writer.height(), writer.width(), writer.height());
        d.documentLayout()->draw(&p, ctx);
        p.restore();
    }
    return p.end();
}
} // namespace neon
