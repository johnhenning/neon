#include "store.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QJsonDocument>
#include <QUuid>
namespace neon {
Store::Store(QString root):root_(QDir(root).absolutePath()) { if(!QDir().mkpath(root_)) throw Error("Cannot create library: "+root_); }
QString Store::safeId(const QString &id) { if(id.isEmpty() || id=="." || id==".." || id.contains('/') || id.contains('\\') || id.contains(QChar(0))) throw Error("Invalid identifier"); return id; }
QString Store::path(const QString &relative) const {
 if(relative.isEmpty() || QDir::isAbsolutePath(relative) || relative.contains('\\')) throw Error("Invalid library path");
 const auto parts=relative.split('/'); QString current=root_;
 for(const auto &part:parts) { safeId(part); current+='/'+part; if(QFileInfo(current).isSymLink()) throw Error("Symlink inside library is not supported: "+relative); }
 return current;
}
bool Store::exists(const QString &relative) const { return QFileInfo::exists(path(relative)); }
QByteArray Store::read(const QString &relative,bool optional) const { QFile f(path(relative)); if(!f.exists() && optional) return {}; if(!f.open(QIODevice::ReadOnly)) throw Error("Cannot read "+relative+": "+f.errorString()); if(f.size()>128*1024*1024) throw Error("File exceeds safety limit: "+relative); return f.readAll(); }
QJsonObject Store::object(const QString &r,bool optional) const { auto b=read(r,optional); if(b.isEmpty() && optional)return {}; QJsonParseError e; auto d=QJsonDocument::fromJson(b,&e); if(e.error!=QJsonParseError::NoError || !d.isObject())throw Error("Invalid JSON object: "+r); return d.object(); }
QJsonArray Store::array(const QString &r,bool optional) const { auto b=read(r,optional); if(b.isEmpty() && optional)return {}; QJsonParseError e; auto d=QJsonDocument::fromJson(b,&e); if(e.error!=QJsonParseError::NoError || !d.isArray())throw Error("Invalid JSON array: "+r); return d.array(); }
QByteArray Store::encode(const QJsonObject &o){return QJsonDocument(o).toJson(QJsonDocument::Indented);}
QByteArray Store::encode(const QJsonArray &a){return QJsonDocument(a).toJson(QJsonDocument::Indented);}
QString Store::id(const QString &p){return p+QUuid::createUuid().toString(QUuid::WithoutBraces);}
void Store::write(const QString &r,const QByteArray &bytes){auto target=path(r); if(!QDir().mkpath(QFileInfo(target).absolutePath()))throw Error("Cannot create parent directory"); QSaveFile f(target); f.setDirectWriteFallback(false); if(!f.open(QIODevice::WriteOnly) || f.write(bytes)!=bytes.size() || !f.commit())throw Error("Could not save "+r+": "+f.errorString());}
void Store::transaction(const QMap<QString,QByteArray> &files){
 if(files.isEmpty())return;
 // A committed journal is replayed after interruption. Each destination is atomic.
 QJsonObject entries; for(auto i=files.cbegin();i!=files.cend();++i){path(i.key());entries[i.key()]=QString::fromLatin1(i.value().toBase64());}
 write(".neon-transaction.json",encode(entries));
 for(auto i=files.cbegin();i!=files.cend();++i)write(i.key(),i.value());
 if(!QFile::remove(path(".neon-transaction.json")))throw Error("Saved files, but journal cleanup failed");
}
void Store::recover(){if(!exists(".neon-transaction.json"))return; auto entries=object(".neon-transaction.json");for(auto i=entries.begin();i!=entries.end();++i){if(!i.value().isString())throw Error("Invalid recovery journal");write(i.key(),QByteArray::fromBase64(i.value().toString().toLatin1()));}if(!QFile::remove(path(".neon-transaction.json")))throw Error("Cannot remove recovered journal");}
void Store::initialize(){recover();if(!exists("library.json"))write("library.json",encode(QJsonObject{{"authorName",""},{"pageTheme","night"},{"shelves",QJsonArray{QJsonObject{{"id","shelf-1"},{"name","Works in Progress"},{"bookIds",QJsonArray{}}}}}}));else object("library.json");}
QStringList Store::bookIds()const {QStringList ids;for(const auto &d:QDir(root_).entryList({"book-*"},QDir::Dirs|QDir::NoDotAndDotDot)){if(exists(d+"/book.json"))ids<<d;}return ids;}
}
