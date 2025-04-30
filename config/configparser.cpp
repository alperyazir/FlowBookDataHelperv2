#include "configparser.h"

#include <QFile>
#include <QDir>
#include <QJsonParseError>
#include <QJsonObject>
#include <fstream>
#include <string>
#include <sstream>
#include <QRegularExpression>
#include <QQmlContext>

#include <QHostInfo>

bool BookSet::initialize(const QString &config_path)
{
    QFile inFile(config_path + "/config.json");
    if (!inFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "Error while opening config file";
        return false;
    }
    QByteArray data = inFile.readAll();
    inFile.close();

    QJsonParseError errorPtr;
    QJsonDocument doc = QJsonDocument::fromJson(data, &errorPtr);
    if (doc.isNull()) {
        qDebug() << "Config file parsing failed";
    } else {
        //        qDebug() << doc;
    }

    auto root = doc.object();

    _publisherName = root["publisher_name"].toString();
    _publisherLogoPath = root["publisher_logo_path"].toString();
    _publisherFullLogoPath = root["publisher_full_logo_path"].toString();
    _fullscreen = root["fullscreen"].toBool();
    _bookTitle = root["book_title"].toString();
    _bookCover = root["book_cover"].toString();
    _language = root["language"].toString();
    auto bks = root["books"].toArray();
    _bookCount = bks.size();
    for (auto const &b : bks) {
        auto bObj = b.toObject();

        Book *book = new Book;
        book->_type = bObj["type"].toInt();
        book->_name = bObj["name"].toString();
        book->_isModuleSideLeft = bObj["is_module_side_left"].toBool();
        book->_modules = handleBooksModules(bObj["modules"].toArray());
        // adding all pages and all games to a single vector
        for (Module *m: book->_modules) {
            for(Page *p: m->_pages) {
                book->_pages.push_back(p);
            }

            for (Game *g: m->_games) {
                book->_games.push_back(g);
            }
        }
        _books.push_back(book);
    }
    qDebug() << "Reading Book is succesfull";
    return true;
}

QVector<Module*> BookSet::handleBooksModules(const QJsonArray &doc)
{
    QVector<Module*> modules;
    for (const auto & m : doc) {
        auto mObj = m.toObject();
        Module *module = new Module;
        module->_type = mObj["type"].toString();
        module->_name = mObj["name"].toString();

        // GAMES
        auto gArr = mObj["games"].toArray();
        for (const auto &g : gArr) {
            auto gObj = g.toObject();
            Game *game = new Game;
            game->_name = gObj["name"].toString();
            game->_type = gObj["type"].toString();
            game->_imagePath = gObj["image_path"].toString();
            auto sWords = gObj["secretwords"].toArray();
            for (const auto &sw : sWords) {
                game->_secretwords.push_back(sw.toString());
            }
            auto sRules = gObj["rules"].toArray();
            for (const auto &sr : sRules) {
                game->_rules.push_back(sr.toString());
            }
            game->_imageCover = gObj["cover_image_path"].toString();

            auto qQuestions = gObj["quiz_questions"].toArray();
            for (const auto &sq : qQuestions) {
                auto qObj = sq.toObject();

                QuizGameQuestion * question = new QuizGameQuestion;
                question->_question = qObj["question"].toString();
                question->_optionA = qObj["optionA"].toString();
                question->_optionB = qObj["optionB"].toString();
                question->_optionC = qObj["optionC"].toString();
                question->_optionD = qObj["optionD"].toString();
                question->_optionE = qObj["optionE"].toString();
                question->_correctAnswer = qObj["correctAnswer"].toString();
                game->_quizGameQuestions.push_back(question);
            }

            auto sQuestions = gObj["sentence_questions"].toArray();

            for (const auto &sq : sQuestions) {
                auto qObj = sq.toObject();

                SentenceGameQuestion * question = new SentenceGameQuestion;
                auto words = qObj["words"].toArray();
                for (const auto &word : words) {
                    question->_words.push_back(word.toString());
                }
                game->_sentenceGameQuestions.push_back(question);
            }
            auto mImages = gObj["memory_images"].toArray();
            for (const auto &mi : mImages) {
                auto mObj = mi.toObject();

                MemoryGameImages * question = new MemoryGameImages;
                question->_image = mObj["image_path"].toString();
                game->_memoryGameImages.push_back(question);
            }

            module->_games.push_back(game);
        }
        // PAGES
        auto cnts = mObj["pages"].toArray();
        for (const auto &c : cnts) {
            auto cObj = c.toObject();
            Page *page = new Page;
            page->_page_number = cObj["page_number"].toInt();
            page->_image_path = cObj["image_path"].toString();

            auto sctns = cObj["sections"].toArray();

            for (const auto &s : sctns) {
                auto sObj = s.toObject();
                Section *section = new Section;
                section->_title = sObj["title"].toString();
                section->_type = sObj["type"].toString();
                section->_audio_path = sObj["audio_path"].toString();


                Video *video = new Video;
                video->_path = sObj["video_path"].toString();
                video->_subtitles = getSubtitles(video->_path);
                section->_video = video;

                auto scObj = sObj["coords"].toObject();
                section->_coords = QRect(scObj["x"].toInt(), scObj["y"].toInt(), scObj["w"].toInt(), scObj["h"].toInt());
                // magnifier
                scObj = sObj["magnifier"].toObject();
                auto scCoord = scObj["coords"].toObject();
                Magnifier *m = new Magnifier;
                m->_coords = QRect(scCoord["x"].toInt(), scCoord["y"].toInt(), scCoord["w"].toInt(), scCoord["h"].toInt());
                m->_sectionPath = scObj["section_path"].toString();
                section->_magnifier = m;

                auto ftfields = sObj["freeTextFields"].toArray();
                for (const auto &f : ftfields) {
                    auto fcOjb= f.toObject()["coords"].toObject();
                    FreeTextFields *field = new FreeTextFields;
                    field->_coords = QRect(fcOjb["x"].toInt(), fcOjb["y"].toInt(), fcOjb["w"].toInt(), fcOjb["h"].toInt());
                    section->_freeTextFields.push_back(field);
                }

                // Activity
                scObj = sObj["activity"].toObject();
                Activity *act = new Activity;
                act->_type = scObj["type"].toString();
                act->_section_path = scObj["section_path"].toString();
                act->_header_text = scObj["headerText"].toString();
                act->_circleCount = scObj["circleCount"].toInt();
                act->_markCount = scObj["markCount"].toInt();
                act->_isTrueFalseEnabled = scObj["isTrueFalseEnabled"].toBool();
                act->_isTextOnLeft = scObj["isTextOnLeft"].toBool();
                act->_textFontSize = scObj["textFontSize"].toInt();
                cObj = scObj["coords"].toObject();
                act->_coords = QRect(cObj["x"].toInt(), cObj["y"].toInt(), cObj["w"].toInt(), cObj["h"].toInt());

                auto actansws = scObj["answer"].toArray();

                for (const auto &a : actansws) {
                    auto aObj = a.toObject();
                    Answer *answer = new Answer;
                    answer->_isCorrect = aObj["isCorrect"].toBool();
                    answer->_realAnswer = aObj["real_answer"].toString();
                    answer->_text = aObj["text"].toString();
                    answer->_diagonal = aObj["diagonal"].toBool();
                    answer->_diagonalSide = aObj["diagonal_side"].toString();
                    answer->_no = aObj["no"].toInt();
                    auto cObj = aObj["coords"].toObject();
                    answer->_coords = QRect(cObj["x"].toInt(), cObj["y"].toInt(), cObj["w"].toInt(), cObj["h"].toInt());


                    auto larr = aObj["letters"].toArray();
                    for (const auto &le : larr) {
                        auto lObj = le.toObject();
                        Letter *l = new Letter;
                        l->_text = lObj["text"].toString();
                        auto lcoords = lObj["coords"].toObject();
                        l->_coords = QRect(lcoords["x"].toInt(), lcoords["y"].toInt(), lcoords["w"].toInt(), lcoords["h"].toInt());

                        answer->_letters.push_back(l);
                    }
                    auto grpArr = aObj["group"].toArray();
                    for (const auto &g : grpArr) {
                        answer->_group.push_back(g.toString());
                    }

                    act->_answers.push_back(answer);
                }
                auto actArr = scObj["sentences"].toArray();
                for (const auto &a : actArr) {
                    Sentences *s = new Sentences;
                    auto sObj = a.toObject();
                    s->_sentence = sObj["sentence"].toString();
                    s->_sentenceAfter = sObj["sentence_after"].toString();
                    s->_word = sObj["word"].toString();
                    s->_imagePath = sObj["image_path"].toString();
                    act->_sentences.push_back(s);
                }

                actArr = scObj["words"].toArray();
                for (const auto &a : actArr) {
                    act->_words.push_back(a.toString());
                }

                actArr = scObj["match_words"].toArray();
                for (const auto &a : actArr) {
                    MatchWord *s = new MatchWord;
                    auto sObj = a.toObject();
                    s->_word = sObj["word"].toString();
                    s->_imagePath = sObj["image_path"].toString();
                    act->_matchWord.push_back(s);
                }


                actArr = scObj["circle_extra"].toArray();
                for (const auto &ce : actArr) {
                    auto ceObj = ce.toObject();
                    CircleExtra *c = new CircleExtra;
                    c->_type = ceObj["type"].toString();
                    c->_text = ceObj["text"].toString();
                    auto ccoords = ceObj["coords"].toObject();
                    c->_coords = QRect(ccoords["x"].toInt(), ccoords["y"].toInt(), ccoords["w"].toInt(), ccoords["h"].toInt());
                    act->_circleExtra.push_back(c);
                }

                section->_activity = act;
                scObj = sObj["show_all_answers"].toObject();
                section->_show_all_answers = QRect(scObj["x"].toInt(), scObj["y"].toInt(), scObj["w"].toInt(), scObj["h"].toInt());
                scObj = sObj["lock_screen"].toObject();
                section->_lock_screen = QRect(scObj["x"].toInt(), scObj["y"].toInt(), scObj["w"].toInt(), scObj["h"].toInt());

                auto answs = sObj["answer"].toArray();

                for (const auto &a : answs) {
                    auto aObj = a.toObject();
                    Answer *answer = new Answer;
                    answer->_text = aObj["text"].toString();
                    answer->_no = aObj["no"].toInt();
                    answer->_diagonal = aObj["diagonal"].toBool();
                    answer->_diagonalSide = aObj["diagonal_side"].toString();
                    auto cObj = aObj["coords"].toObject();
                    answer->_coords = QRect(cObj["x"].toInt(), cObj["y"].toInt(), cObj["w"].toInt(), cObj["h"].toInt());
                    answer->_isCorrect = aObj["isCorrect"].toBool();
                    cObj = aObj["sourceCoords"].toObject();
                    answer->_sourceCoords = QRect(cObj["x"].toInt(), cObj["y"].toInt(), cObj["w"].toInt(), cObj["h"].toInt());
                    answer->_sourceText = cObj["text"].toString();
                    answer->_rotation = aObj["rotation"].toDouble();
                    answer->_color = aObj["color"].toString();
                    answer->_isRound = aObj["isRound"].toBool();
                    answer->_opacity = aObj["opacity"].toDouble();
                    cObj = aObj["rectBegin"].toObject();
                    answer->_rectBegin = QRect(cObj["x"].toInt(), cObj["y"].toInt(), cObj["w"].toInt(), cObj["h"].toInt());
                    cObj = aObj["rectEnd"].toObject();
                    answer->_rectEnd = QRect(cObj["x"].toInt(), cObj["y"].toInt(), cObj["w"].toInt(), cObj["h"].toInt());
                    cObj = aObj["lineBegin"].toObject();
                    answer->_lineBegin = QPoint(cObj["x"].toInt(), cObj["y"].toInt());
                    cObj = aObj["lineEnd"].toObject();
                    answer->_lineEnd = QPoint(cObj["x"].toInt(), cObj["y"].toInt());
                    section->_answers.push_back(answer);
                }

                auto audioExtraObj = sObj["audio_extra"].toObject();
                AudioExtra *ae = new AudioExtra;
                ae->_path = audioExtraObj["path"].toString();
                cObj = audioExtraObj["coords"].toObject();
                ae->_coords = QRect(cObj["x"].toInt(), cObj["y"].toInt(), cObj["w"].toInt(), cObj["h"].toInt());
                section->_audio_extra = ae;

                auto caObj = sObj["checkAnswer"].toObject();
                section->_checkAnswer = QRect(caObj["x"].toInt(), caObj["y"].toInt(), caObj["w"].toInt(), caObj["h"].toInt());

                page->_sections.push_back(section);
            }
            module->_pages.push_back(page);
        }
        // }
        modules.push_back(module);
    }
    return modules;
}

QVector<Subtitles *> BookSet::getSubtitles(QString videoPath)
{
    // Uzantıyı değiştirmek için son noktadan itibaren uzantıyı bul
    int dotIndex = videoPath.lastIndexOf('.');
    if (dotIndex == -1) {
        return {};
    }
    QString appDir = QGuiApplication::applicationDirPath();

#ifdef Q_OS_MAC
    appDir += "/../../../data/";
#endif

    // Dosya adını ve uzantısını ayır
    QString fileName = appDir + videoPath.left(dotIndex);

    // Yeni uzantıyı ekleyerek dosya adını oluştur
    QString srtFilePath = fileName + ".srt";

    QVector<Subtitles*> subtitles;

    QFile file(srtFilePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "Dosya açılamadı:" << srtFilePath;
        return subtitles;
    }

    QTextStream in(&file);



    QVector<QString> subs;
    while (!in.atEnd()) {
        subs.push_back(in.readLine().trimmed());
    }

    int counter = 1;
    for (int i = 0; i < subs.size();) {
        if(subs.at(i).toInt() == counter) {
            Subtitles *sub = new Subtitles;
            sub->_id = subs.at(i).toInt();
            i++;
            QStringList times = subs.at(i).split(" --> ");
            QString startTimeStr = times[0];
            QString endTimeStr = times[1];
            QRegularExpression timeRegex("(\\d{2}):(\\d{2}):(\\d{2}),(\\d{3})");
            QRegularExpressionMatch startTimeMatch = timeRegex.match(startTimeStr);
            QRegularExpressionMatch endTimeMatch = timeRegex.match(endTimeStr);
            if (startTimeMatch.hasMatch() && endTimeMatch.hasMatch()) {
                int h1 = startTimeMatch.captured(1).toInt();
                int m1 = startTimeMatch.captured(2).toInt();
                int s1 = startTimeMatch.captured(3).toInt();
                int ms1 = startTimeMatch.captured(4).toInt();

                int h2 = endTimeMatch.captured(1).toInt();
                int m2 = endTimeMatch.captured(2).toInt();
                int s2 = endTimeMatch.captured(3).toInt();
                int ms2 = endTimeMatch.captured(4).toInt();

                sub->_startTime = h1 * 3600000 + m1 * 60000 + s1 * 1000 + ms1;
                sub->_endTime =  h2 * 3600000 + m2 * 60000 + s2 * 1000 + ms2;
            }

            i++;
            QString subContent;
            while(!subs.at(i).isEmpty()) {
                subContent.append(subs.at(i)).append(" ");
                i++;
            }
            i++;
            sub->_subtitle = subContent;
            subtitles.push_back(sub);
        }
        counter++;
    }

    return subtitles;
}

ConfigParser::ConfigParser(QObject *parent) : QObject(parent) {
    refreshRecentProjects();
}

bool ConfigParser::initialize(bool isFromFileSystem, const QString &path)
{
    if(!isFromFileSystem) {
        QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
        appDir += "/../../../books/";
#else
        appDir += "/books/";
#endif

        QDir directory = appDir;
        directory.setFilter(QDir::Dirs | QDir::NoDotAndDotDot);
        auto dirList = directory.entryList();
        bool result = true;
        for (const auto& d : dirList) {
            BookSet *bset = new BookSet;
            bset->_bookDirectoryName = d;
            result = bset->initialize(directory.path() + "/" + d);
            _bookSets.push_back(bset);
            //saveEncryptedJsonToFile(R"({"test": "test", "alper":"alper"})");
            //saveEncryptedJsonToFile(getInformation(bset));
        }

        return result;
    }
    _bookSets.clear();
    BookSet *bset = new BookSet;
    _bookSets.push_back(bset);


    bset->initialize(path);
    bset->_bookDirectoryName = path;
    bookSetsChanged();
    return true;
}

QString ConfigParser::getInformation(BookSet *bset)
{
    if (_bookSets.empty()) return "";

    auto hostname = QHostInfo::localHostName();

    QJsonObject doc;

    auto jInfo = readEncryptedJsonFromFile();
    if (jInfo["hostname"].toString() != hostname) {
        doc["hostname"] = hostname;
        doc["first_run_date"] = QString::number(QDateTime::currentSecsSinceEpoch());
    } else {
        doc["hostname"] = hostname;
        doc["first_run_date"] = jInfo["first_run_date"].toString();
    }
    doc["publisher_name"] = bset->_publisherName;
    doc["book_title"] = bset->_bookTitle;

    _publisher_name = bset->_publisherName;
    _hostname = hostname;
    _book_title = bset->_bookTitle;

    _first_run_date = doc["first_run_date"].toString();

    QJsonDocument jsonDoc(doc);
    QString res = jsonDoc.toJson(QJsonDocument::Compact);
    return res;
}
void ConfigParser::saveEncryptedJsonToFile(const QString& jsonString) {
    QByteArray byteArray = jsonString.toUtf8();

    QByteArray key = "thisshouldbeasecret";
    for (int i = 0; i < byteArray.size(); ++i) {
        byteArray[i] = byteArray[i] ^ key[i % key.size()];
    }

    QFile file("fbinf");
    if (file.open(QIODevice::WriteOnly)) {
        file.write(byteArray);
        file.close();
    } else {
        qWarning("Dosya açılamadı.");
    }
}

void ConfigParser::refreshRecentProjects()
{
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../../books/";
#else
    appDir += "/books/";
#endif
    QDir directory = appDir;
    directory.setFilter(QDir::Dirs | QDir::NoDotAndDotDot);
    auto dirList = directory.entryList();
    QStringList recentProjects;
    for (const auto& d : dirList) {
        recentProjects.append(d);
    }
    setRecentProject(recentProjects);
}

QStringList ConfigParser::recentProject() const
{
    return _recentProject;
}

void ConfigParser::setRecentProject(const QStringList &newRecentProject)
{
    if (_recentProject == newRecentProject)
        return;
    _recentProject = newRecentProject;
    emit recentProjectChanged();
}


QString ConfigParser::decryptData(const QByteArray& byteArray, const QByteArray& key) {
    QByteArray decryptedData = byteArray;

    for (int i = 0; i < decryptedData.size(); ++i) {
        decryptedData[i] = decryptedData[i] ^ key[i % key.size()];
    }

    return QString::fromUtf8(decryptedData);
}

QJsonObject ConfigParser::readEncryptedJsonFromFile() {
    QFile file("fbinf");
    if (file.open(QIODevice::ReadOnly)) {
        QByteArray byteArray = file.readAll();
        file.close();

        QByteArray key = "thisshouldbeasecret";
        QString decryptedData = decryptData(byteArray, key);

        // JSON string'i QJsonObject'e çevirme
        QJsonDocument jsonDoc = QJsonDocument::fromJson(decryptedData.toUtf8());
        if (!jsonDoc.isNull() && jsonDoc.isObject()) {
            return jsonDoc.object();
        }
    } else {
        qWarning("Dosya açılamadı.");
    }
    return QJsonObject();
}
