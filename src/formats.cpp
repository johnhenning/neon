#include "formats.h"
#include "store.h"
#include <QTextDocument>
#include <QRegularExpression>
namespace neon {
QString Formats::plain(const QString &h){QTextDocument d;d.setHtml(h);return d.toPlainText();}
int Formats::words(const QString &h){static const QRegularExpression re(QStringLiteral("[\\p{L}\\p{N}]+(?:[’'\\-][\\p{L}\\p{N}]+)*"));auto it=re.globalMatch(plain(h));int n=0;while(it.hasNext()){it.next();++n;}return n;}
QString Formats::html(const Manuscript &b){QString s="<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body><h1>"+b.title.toHtmlEscaped()+"</h1><p>"+b.author.toHtmlEscaped()+"</p>";for(const auto &c:b.chapters)s+="<h2>"+c.title.toHtmlEscaped()+"</h2>"+c.html;return s+"</body></html>";}
}
