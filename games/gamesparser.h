#ifndef GAMESPARSER_H
#define GAMESPARSER_H

#include <QObject>
#include <QString>
#include <QVector>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QVariantList>
#include <QFile>
#include <QDebug>
#include <QMutex>
#include <QMutexLocker>
#include <QFileInfo>
#include <QDir>
#include <exception>

struct QuizAnswer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    Q_PROPERTY(bool isCorrect READ isCorrect WRITE setIsCorrect NOTIFY isCorrectChanged)

public:
    explicit QuizAnswer(QObject *parent = nullptr) : QObject(parent), _isCorrect(false) {}

    QString _text;
    bool _isCorrect;

    QString text() const { return _text; }
    void setText(const QString &text) {
        if (_text != text) {
            _text = text;
            emit textChanged();
        }
    }

    bool isCorrect() const { return _isCorrect; }
    void setIsCorrect(bool isCorrect) {
        if (_isCorrect != isCorrect) {
            _isCorrect = isCorrect;
            emit isCorrectChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["text"] = _text;
        obj["isCorrect"] = _isCorrect;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setText(obj["text"].toString());
        setIsCorrect(obj["isCorrect"].toBool());
    }

signals:
    void textChanged();
    void isCorrectChanged();
};

struct QuizQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString question READ question WRITE setQuestion NOTIFY questionChanged)
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)
    Q_PROPERTY(QVariantList answers READ answers WRITE setAnswers NOTIFY answersChanged)

public:
    explicit QuizQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QString _question;
    QString _image;  // OPTIONAL
    QVector<QuizAnswer*> _answers;

    QString question() const { return _question; }
    void setQuestion(const QString &question) {
        if (_question != question) {
            _question = question;
            emit questionChanged();
        }
    }

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    QVariantList answers() const {
        QVariantList list;
        for (QuizAnswer *answer : _answers) {
            list << QVariant::fromValue(answer);
        }
        return list;
    }

    void setAnswers(const QVariantList &answers) {
        _answers.clear();
        for (const QVariant &variant : answers) {
            QuizAnswer *answer = qobject_cast<QuizAnswer*>(variant.value<QObject*>());
            if (answer) {
                _answers.append(answer);
            }
        }
        emit answersChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["question"] = _question;
        if (!_image.isEmpty()) obj["image"] = _image;

        QJsonArray answersArray;
        for (const QuizAnswer *answer : _answers) {
            if (answer) { // Null check eklendi
                answersArray.append(answer->toJson());
            }
        }
        obj["answers"] = answersArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setQuestion(obj["question"].toString());
        if (obj.contains("image")) {
            setImage(obj["image"].toString());
        }

        QJsonArray answersArray = obj["answers"].toArray();
        _answers.clear();
        for (const QJsonValue &value : answersArray) {
            QuizAnswer *answer = new QuizAnswer(this);
            answer->fromJson(value.toObject());
            _answers.append(answer);
        }
        emit answersChanged();
    }

signals:
    void questionChanged();
    void imageChanged();
    void answersChanged();
};

struct QuizGame : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList questions READ questions WRITE setQuestions NOTIFY questionsChanged)

public:
    explicit QuizGame(QObject *parent = nullptr) : QObject(parent) {}

    QVector<QuizQuestion*> _questions;

    QVariantList questions() const {
        QVariantList list;
        for (QuizQuestion *question : _questions) {
            list << QVariant::fromValue(question);
        }
        return list;
    }

    void setQuestions(const QVariantList &questions) {
        // CRASH-SAFE: Eski objeler için memory cleanup
        for (QuizQuestion *question : _questions) {
            if (question) {
                question->deleteLater();
            }
        }
        _questions.clear();
        
        for (const QVariant &variant : questions) {
            QuizQuestion *question = qobject_cast<QuizQuestion*>(variant.value<QObject*>());
            if (question) {
                _questions.append(question);
            }
        }
        emit questionsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["type"] = "quiz";

        QJsonArray questionsArray;
        for (const QuizQuestion *question : _questions) {
            if (question) { // Null check eklendi
                questionsArray.append(question->toJson());
            }
        }
        obj["questions"] = questionsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray questionsArray = obj["questions"].toArray();
        _questions.clear();
        for (const QJsonValue &value : questionsArray) {
            QuizQuestion *question = new QuizQuestion(this);
            question->fromJson(value.toObject());
            _questions.append(question);
        }
        emit questionsChanged();
    }

signals:
    void questionsChanged();
};

// Memory Game Structures
struct MemoryQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)
    Q_PROPERTY(QString audio READ audio WRITE setAudio NOTIFY audioChanged)

public:
    explicit MemoryQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QString _image;
    QString _audio;

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    QString audio() const { return _audio; }
    void setAudio(const QString &audio) {
        if (_audio != audio) {
            _audio = audio;
            emit audioChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["image"] = _image;
        obj["audio"] = _audio;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setImage(obj["image"].toString());
        setAudio(obj["audio"].toString());
    }

signals:
    void imageChanged();
    void audioChanged();
};

struct MemoryGame : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList questions READ questions WRITE setQuestions NOTIFY questionsChanged)

public:
    explicit MemoryGame(QObject *parent = nullptr) : QObject(parent) {}

    QVector<MemoryQuestion*> _questions;

    QVariantList questions() const {
        QVariantList list;
        for (MemoryQuestion *question : _questions) {
            list << QVariant::fromValue(question);
        }
        return list;
    }

    void setQuestions(const QVariantList &questions) {
        // CRASH-SAFE: Eski objeler için memory cleanup
        for (MemoryQuestion *question : _questions) {
            if (question) {
                question->deleteLater();
            }
        }
        _questions.clear();
        
        for (const QVariant &variant : questions) {
            MemoryQuestion *question = qobject_cast<MemoryQuestion*>(variant.value<QObject*>());
            if (question) {
                _questions.append(question);
            }
        }
        emit questionsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["type"] = "memory";

        QJsonArray questionsArray;
        for (const MemoryQuestion *question : _questions) {
            if (question) { // Null check eklendi
                questionsArray.append(question->toJson());
            }
        }
        obj["questions"] = questionsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray questionsArray = obj["questions"].toArray();
        _questions.clear();
        for (const QJsonValue &value : questionsArray) {
            MemoryQuestion *question = new MemoryQuestion(this);
            question->fromJson(value.toObject());
            _questions.append(question);
        }
        emit questionsChanged();
    }

signals:
    void questionsChanged();
};

struct OrderQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList words READ words WRITE setWords NOTIFY wordsChanged)

public:
    explicit OrderQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QVector<QString> _words;

    QVariantList words() const {
        QVariantList list;
        for (const QString &word : _words) {
            list << word;
        }
        return list;
    }

    void setWords(const QVariantList &words) {
        _words.clear();
        for (const QVariant &variant : words) {
            if (variant.canConvert<QString>()) {
                _words.append(variant.toString());
            }
        }
        emit wordsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        QJsonArray wordsArray;
        for (const QString &word : _words) {
            wordsArray.append(word);
        }
        obj["words"] = wordsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray wordsArray = obj["words"].toArray();
        _words.clear();
        for (const QJsonValue &value : wordsArray) {
            _words.append(value.toString());
        }
        emit wordsChanged();
    }

signals:
    void wordsChanged();
};

struct OrderGame : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList questions READ questions WRITE setQuestions NOTIFY questionsChanged)

public:
    explicit OrderGame(QObject *parent = nullptr) : QObject(parent) {}

    QVector<OrderQuestion*> _questions;

    QVariantList questions() const {
        QVariantList list;
        for (OrderQuestion *question : _questions) {
            list << QVariant::fromValue(question);
        }
        return list;
    }

    void setQuestions(const QVariantList &questions) {
        // CRASH-SAFE: Eski objeler için memory cleanup
        for (OrderQuestion *question : _questions) {
            if (question) {
                question->deleteLater();
            }
        }
        _questions.clear();
        
        for (const QVariant &variant : questions) {
            OrderQuestion *question = qobject_cast<OrderQuestion*>(variant.value<QObject*>());
            if (question) {
                _questions.append(question);
            }
        }
        emit questionsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["type"] = "order";

        QJsonArray questionsArray;
        for (const OrderQuestion *question : _questions) {
            if (question) { // Null check eklendi
                questionsArray.append(question->toJson());
            }
        }
        obj["questions"] = questionsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray questionsArray = obj["questions"].toArray();
        _questions.clear();
        for (const QJsonValue &value : questionsArray) {
            OrderQuestion *question = new OrderQuestion(this);
            question->fromJson(value.toObject());
            _questions.append(question);
        }
        emit questionsChanged();
    }

signals:
    void questionsChanged();
};

struct SelectorAnswer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)
    Q_PROPERTY(bool isCorrect READ isCorrect WRITE setIsCorrect NOTIFY isCorrectChanged)

public:
    explicit SelectorAnswer(QObject *parent = nullptr) : QObject(parent), _isCorrect(false) {}

    QString _text;
    QString _image;  // Always present in selector answers
    bool _isCorrect;

    QString text() const { return _text; }
    void setText(const QString &text) {
        if (_text != text) {
            _text = text;
            emit textChanged();
        }
    }

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    bool isCorrect() const { return _isCorrect; }
    void setIsCorrect(bool isCorrect) {
        if (_isCorrect != isCorrect) {
            _isCorrect = isCorrect;
            emit isCorrectChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["text"] = _text;
        obj["image"] = _image;
        obj["isCorrect"] = _isCorrect;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setText(obj["text"].toString());
        setImage(obj["image"].toString());
        setIsCorrect(obj["isCorrect"].toBool());
    }

signals:
    void textChanged();
    void imageChanged();
    void isCorrectChanged();
};

struct SelectorQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString question READ question WRITE setQuestion NOTIFY questionChanged)
    Q_PROPERTY(QString header READ header WRITE setHeader NOTIFY headerChanged)
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)
    Q_PROPERTY(QString audio READ audio WRITE setAudio NOTIFY audioChanged)
    Q_PROPERTY(QString video READ video WRITE setVideo NOTIFY videoChanged)
    Q_PROPERTY(QVariantList answers READ answers WRITE setAnswers NOTIFY answersChanged)

public:
    explicit SelectorQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QString _question; // OPTIONAL - text question
    QString _header;  // OPTIONAL - header text
    QString _image;   // OPTIONAL
    QString _audio;   // OPTIONAL
    QString _video;   // OPTIONAL
    QVector<SelectorAnswer*> _answers;

    QString question() const { return _question; }
    void setQuestion(const QString &question) {
        if (_question != question) {
            _question = question;
            emit questionChanged();
        }
    }

    QString header() const { return _header; }
    void setHeader(const QString &header) {
        if (_header != header) {
            _header = header;
            emit headerChanged();
        }
    }

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    QString audio() const { return _audio; }
    void setAudio(const QString &audio) {
        if (_audio != audio) {
            _audio = audio;
            emit audioChanged();
        }
    }

    QString video() const { return _video; }
    void setVideo(const QString &video) {
        if (_video != video) {
            _video = video;
            emit videoChanged();
        }
    }

    QVariantList answers() const {
        QVariantList list;
        for (SelectorAnswer *answer : _answers) {
            list << QVariant::fromValue(answer);
        }
        return list;
    }

    void setAnswers(const QVariantList &answers) {
        _answers.clear();
        for (const QVariant &variant : answers) {
            SelectorAnswer *answer = qobject_cast<SelectorAnswer*>(variant.value<QObject*>());
            if (answer) {
                _answers.append(answer);
            }
        }
        emit answersChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        if (!_question.isEmpty()) obj["question"] = _question;
        if (!_header.isEmpty()) obj["header"] = _header;
        if (!_image.isEmpty()) obj["image"] = _image;
        if (!_audio.isEmpty()) obj["audio"] = _audio;
        if (!_video.isEmpty()) obj["video"] = _video;

        QJsonArray answersArray;
        for (const SelectorAnswer *answer : _answers) {
            if (answer) { // Null check eklendi
                answersArray.append(answer->toJson());
            }
        }
        obj["answers"] = answersArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        if (obj.contains("question")) setQuestion(obj["question"].toString());
        if (obj.contains("header")) setHeader(obj["header"].toString());
        if (obj.contains("image")) setImage(obj["image"].toString());
        if (obj.contains("audio")) setAudio(obj["audio"].toString());
        if (obj.contains("video")) setVideo(obj["video"].toString());

        QJsonArray answersArray = obj["answers"].toArray();
        _answers.clear();
        for (const QJsonValue &value : answersArray) {
            SelectorAnswer *answer = new SelectorAnswer(this);
            answer->fromJson(value.toObject());
            _answers.append(answer);
        }
        emit answersChanged();
    }

signals:
    void questionChanged();
    void headerChanged();
    void imageChanged();
    void audioChanged();
    void videoChanged();
    void answersChanged();
};

struct SelectorGame : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList questions READ questions WRITE setQuestions NOTIFY questionsChanged)

public:
    explicit SelectorGame(QObject *parent = nullptr) : QObject(parent) {}

    QVector<SelectorQuestion*> _questions;

    QVariantList questions() const {
        QVariantList list;
        for (SelectorQuestion *question : _questions) {
            list << QVariant::fromValue(question);
        }
        return list;
    }

    void setQuestions(const QVariantList &questions) {
        _questions.clear();
        for (const QVariant &variant : questions) {
            SelectorQuestion *question = qobject_cast<SelectorQuestion*>(variant.value<QObject*>());
            if (question) {
                _questions.append(question);
            }
        }
        emit questionsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["type"] = "selector";

        QJsonArray questionsArray;
        for (const SelectorQuestion *question : _questions) {
            if (question) { // Null check eklendi
                questionsArray.append(question->toJson());
            }
        }
        obj["questions"] = questionsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray questionsArray = obj["questions"].toArray();
        _questions.clear();
        for (const QJsonValue &value : questionsArray) {
            SelectorQuestion *question = new SelectorQuestion(this);
            question->fromJson(value.toObject());
            _questions.append(question);
        }
        emit questionsChanged();
    }

signals:
    void questionsChanged();
};

// Builder Game Structures
struct BuilderQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)
    Q_PROPERTY(QString audio READ audio WRITE setAudio NOTIFY audioChanged)
    Q_PROPERTY(QString video READ video WRITE setVideo NOTIFY videoChanged)
    Q_PROPERTY(QString question READ question WRITE setQuestion NOTIFY questionChanged)
    Q_PROPERTY(QVariantList words READ words WRITE setWords NOTIFY wordsChanged)

public:
    explicit BuilderQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QString _image;     // OPTIONAL
    QString _audio;     // OPTIONAL
    QString _video;     // OPTIONAL
    QString _question;  // REQUIRED
    QVector<QString> _words;  // REQUIRED

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    QString audio() const { return _audio; }
    void setAudio(const QString &audio) {
        if (_audio != audio) {
            _audio = audio;
            emit audioChanged();
        }
    }

    QString video() const { return _video; }
    void setVideo(const QString &video) {
        if (_video != video) {
            _video = video;
            emit videoChanged();
        }
    }

    QString question() const { return _question; }
    void setQuestion(const QString &question) {
        if (_question != question) {
            _question = question;
            emit questionChanged();
        }
    }

    QVariantList words() const {
        QVariantList list;
        for (const QString &word : _words) {
            list << word;
        }
        return list;
    }

    void setWords(const QVariantList &words) {
        _words.clear();
        for (const QVariant &variant : words) {
            if (variant.canConvert<QString>()) {
                _words.append(variant.toString());
            }
        }
        emit wordsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        if (!_image.isEmpty()) obj["image"] = _image;
        if (!_audio.isEmpty()) obj["audio"] = _audio;
        if (!_video.isEmpty()) obj["video"] = _video;
        obj["question"] = _question;

        QJsonArray wordsArray;
        for (const QString &word : _words) {
            wordsArray.append(word);
        }
        obj["words"] = wordsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        if (obj.contains("image")) setImage(obj["image"].toString());
        if (obj.contains("audio")) setAudio(obj["audio"].toString());
        if (obj.contains("video")) setVideo(obj["video"].toString());
        setQuestion(obj["question"].toString());

        QJsonArray wordsArray = obj["words"].toArray();
        _words.clear();
        for (const QJsonValue &value : wordsArray) {
            _words.append(value.toString());
        }
        emit wordsChanged();
    }

signals:
    void imageChanged();
    void audioChanged();
    void videoChanged();
    void questionChanged();
    void wordsChanged();
};

struct BuilderGame : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList questions READ questions WRITE setQuestions NOTIFY questionsChanged)

public:
    explicit BuilderGame(QObject *parent = nullptr) : QObject(parent) {}

    QVector<BuilderQuestion*> _questions;

    QVariantList questions() const {
        QVariantList list;
        for (BuilderQuestion *question : _questions) {
            list << QVariant::fromValue(question);
        }
        return list;
    }

    void setQuestions(const QVariantList &questions) {
        _questions.clear();
        for (const QVariant &variant : questions) {
            BuilderQuestion *question = qobject_cast<BuilderQuestion*>(variant.value<QObject*>());
            if (question) {
                _questions.append(question);
            }
        }
        emit questionsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["type"] = "builder";

        QJsonArray questionsArray;
        for (const BuilderQuestion *question : _questions) {
            if (question) { // Null check eklendi
                questionsArray.append(question->toJson());
            }
        }
        obj["questions"] = questionsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray questionsArray = obj["questions"].toArray();
        _questions.clear();
        for (const QJsonValue &value : questionsArray) {
            BuilderQuestion *question = new BuilderQuestion(this);
            question->fromJson(value.toObject());
            _questions.append(question);
        }
        emit questionsChanged();
    }

signals:
    void questionsChanged();
};

// Crosspuzzle Game Structures
struct CrosspuzzleAnswer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)

public:
    explicit CrosspuzzleAnswer(QObject *parent = nullptr) : QObject(parent) {}

    QString _text;

    QString text() const { return _text; }
    void setText(const QString &text) {
        if (_text != text) {
            _text = text;
            emit textChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["text"] = _text;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setText(obj["text"].toString());
    }

signals:
    void textChanged();
};

struct CrosspuzzleQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString question READ question WRITE setQuestion NOTIFY questionChanged)
    Q_PROPERTY(QVariantList answers READ answers WRITE setAnswers NOTIFY answersChanged)

public:
    explicit CrosspuzzleQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QString _question;
    QVector<CrosspuzzleAnswer*> _answers;

    QString question() const { return _question; }
    void setQuestion(const QString &question) {
        if (_question != question) {
            _question = question;
            emit questionChanged();
        }
    }

    QVariantList answers() const {
        QVariantList list;
        for (CrosspuzzleAnswer *answer : _answers) {
            list << QVariant::fromValue(answer);
        }
        return list;
    }

    void setAnswers(const QVariantList &answers) {
        // CRASH-SAFE: Eski objeler için memory cleanup
        for (CrosspuzzleAnswer *answer : _answers) {
            if (answer) {
                answer->deleteLater();
            }
        }
        _answers.clear();
        
        for (const QVariant &variant : answers) {
            CrosspuzzleAnswer *answer = qobject_cast<CrosspuzzleAnswer*>(variant.value<QObject*>());
            if (answer) {
                _answers.append(answer);
            }
        }
        emit answersChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["question"] = _question;

        QJsonArray answersArray;
        for (const CrosspuzzleAnswer *answer : _answers) {
            if (answer) { // Null check eklendi
                answersArray.append(answer->toJson());
            }
        }
        obj["answers"] = answersArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setQuestion(obj["question"].toString());

        QJsonArray answersArray = obj["answers"].toArray();
        _answers.clear();
        for (const QJsonValue &value : answersArray) {
            CrosspuzzleAnswer *answer = new CrosspuzzleAnswer(this);
            answer->fromJson(value.toObject());
            _answers.append(answer);
        }
        emit answersChanged();
    }

signals:
    void questionChanged();
    void answersChanged();
};

struct CrosspuzzleGame : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList questions READ questions WRITE setQuestions NOTIFY questionsChanged)

public:
    explicit CrosspuzzleGame(QObject *parent = nullptr) : QObject(parent) {}

    QVector<CrosspuzzleQuestion*> _questions;

    QVariantList questions() const {
        QVariantList list;
        for (CrosspuzzleQuestion *question : _questions) {
            list << QVariant::fromValue(question);
        }
        return list;
    }

    void setQuestions(const QVariantList &questions) {
        _questions.clear();
        for (const QVariant &variant : questions) {
            CrosspuzzleQuestion *question = qobject_cast<CrosspuzzleQuestion*>(variant.value<QObject*>());
            if (question) {
                _questions.append(question);
            }
        }
        emit questionsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["type"] = "crosspuzzle";

        QJsonArray questionsArray;
        for (const CrosspuzzleQuestion *question : _questions) {
            if (question) { // Null check eklendi
                questionsArray.append(question->toJson());
            }
        }
        obj["questions"] = questionsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray questionsArray = obj["questions"].toArray();
        _questions.clear();
        for (const QJsonValue &value : questionsArray) {
            CrosspuzzleQuestion *question = new CrosspuzzleQuestion(this);
            question->fromJson(value.toObject());
            _questions.append(question);
        }
        emit questionsChanged();
    }

signals:
    void questionsChanged();
};

// Race Game Structures
struct RaceAnswer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)
    Q_PROPERTY(bool isCorrect READ isCorrect WRITE setIsCorrect NOTIFY isCorrectChanged)

public:
    explicit RaceAnswer(QObject *parent = nullptr) : QObject(parent), _isCorrect(false) {}

    QString _text;
    QString _image;  // OPTIONAL - some answers have it, some don't
    bool _isCorrect;

    QString text() const { return _text; }
    void setText(const QString &text) {
        if (_text != text) {
            _text = text;
            emit textChanged();
        }
    }

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    bool isCorrect() const { return _isCorrect; }
    void setIsCorrect(bool isCorrect) {
        if (_isCorrect != isCorrect) {
            _isCorrect = isCorrect;
            emit isCorrectChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["text"] = _text;
        if (!_image.isEmpty()) obj["image"] = _image;
        obj["isCorrect"] = _isCorrect;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setText(obj["text"].toString());
        if (obj.contains("image")) {
            setImage(obj["image"].toString());
        }
        setIsCorrect(obj["isCorrect"].toBool());
    }

signals:
    void textChanged();
    void imageChanged();
    void isCorrectChanged();
};

struct RaceQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString audio READ audio WRITE setAudio NOTIFY audioChanged)
    Q_PROPERTY(QString question READ question WRITE setQuestion NOTIFY questionChanged)
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)
    Q_PROPERTY(QVariantList answers READ answers WRITE setAnswers NOTIFY answersChanged)

public:
    explicit RaceQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QString _audio;    // OPTIONAL
    QString _question; // REQUIRED
    QString _image;    // OPTIONAL
    QVector<RaceAnswer*> _answers;

    QString audio() const { return _audio; }
    void setAudio(const QString &audio) {
        if (_audio != audio) {
            _audio = audio;
            emit audioChanged();
        }
    }

    QString question() const { return _question; }
    void setQuestion(const QString &question) {
        if (_question != question) {
            _question = question;
            emit questionChanged();
        }
    }

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    QVariantList answers() const {
        QVariantList list;
        for (RaceAnswer *answer : _answers) {
            list << QVariant::fromValue(answer);
        }
        return list;
    }

    void setAnswers(const QVariantList &answers) {
        _answers.clear();
        for (const QVariant &variant : answers) {
            RaceAnswer *answer = qobject_cast<RaceAnswer*>(variant.value<QObject*>());
            if (answer) {
                _answers.append(answer);
            }
        }
        emit answersChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        if (!_audio.isEmpty()) obj["audio"] = _audio;
        obj["question"] = _question;
        if (!_image.isEmpty()) obj["image"] = _image;

        QJsonArray answersArray;
        for (const RaceAnswer *answer : _answers) {
            if (answer) { // Null check eklendi
                answersArray.append(answer->toJson());
            }
        }
        obj["answers"] = answersArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        if (obj.contains("audio")) setAudio(obj["audio"].toString());
        setQuestion(obj["question"].toString());
        if (obj.contains("image")) setImage(obj["image"].toString());

        QJsonArray answersArray = obj["answers"].toArray();
        _answers.clear();
        for (const QJsonValue &value : answersArray) {
            RaceAnswer *answer = new RaceAnswer(this);
            answer->fromJson(value.toObject());
            _answers.append(answer);
        }
        emit answersChanged();
    }

signals:
    void audioChanged();
    void questionChanged();
    void imageChanged();
    void answersChanged();
};

struct RaceGame : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList questions READ questions WRITE setQuestions NOTIFY questionsChanged)

public:
    explicit RaceGame(QObject *parent = nullptr) : QObject(parent) {}

    QVector<RaceQuestion*> _questions;

    QVariantList questions() const {
        QVariantList list;
        for (RaceQuestion *question : _questions) {
            list << QVariant::fromValue(question);
        }
        return list;
    }

    void setQuestions(const QVariantList &questions) {
        _questions.clear();
        for (const QVariant &variant : questions) {
            RaceQuestion *question = qobject_cast<RaceQuestion*>(variant.value<QObject*>());
            if (question) {
                _questions.append(question);
            }
        }
        emit questionsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["type"] = "race";

        QJsonArray questionsArray;
        for (const RaceQuestion *question : _questions) {
            if (question) { // Null check eklendi
                questionsArray.append(question->toJson());
            }
        }
        obj["questions"] = questionsArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        QJsonArray questionsArray = obj["questions"].toArray();
        _questions.clear();
        for (const QJsonValue &value : questionsArray) {
            RaceQuestion *question = new RaceQuestion(this);
            question->fromJson(value.toObject());
            _questions.append(question);
        }
        emit questionsChanged();
    }

signals:
    void questionsChanged();
};

// Level and main parser structures
struct Level : public QObject {
    Q_OBJECT
    Q_PROPERTY(int level READ level WRITE setLevel NOTIFY levelChanged)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    Q_PROPERTY(QVariantList quizGames READ quizGames WRITE setQuizGames NOTIFY quizGamesChanged)
    Q_PROPERTY(QVariantList memoryGames READ memoryGames WRITE setMemoryGames NOTIFY memoryGamesChanged)
    Q_PROPERTY(QVariantList orderGames READ orderGames WRITE setOrderGames NOTIFY orderGamesChanged)
    Q_PROPERTY(QVariantList selectorGames READ selectorGames WRITE setSelectorGames NOTIFY selectorGamesChanged)
    Q_PROPERTY(QVariantList builderGames READ builderGames WRITE setBuilderGames NOTIFY builderGamesChanged)
    Q_PROPERTY(QVariantList crosspuzzleGames READ crosspuzzleGames WRITE setCrosspuzzleGames NOTIFY crosspuzzleGamesChanged)
    Q_PROPERTY(QVariantList raceGames READ raceGames WRITE setRaceGames NOTIFY raceGamesChanged)

public:
    explicit Level(QObject *parent = nullptr) : QObject(parent), _level(0) {}

    int _level;
    QString _title;
    QVector<QuizGame*> _quizGames;
    QVector<MemoryGame*> _memoryGames;
    QVector<OrderGame*> _orderGames;
    QVector<SelectorGame*> _selectorGames;
    QVector<BuilderGame*> _builderGames;
    QVector<CrosspuzzleGame*> _crosspuzzleGames;
    QVector<RaceGame*> _raceGames;

    int level() const { return _level; }
    void setLevel(int level) {
        if (_level != level) {
            _level = level;
            emit levelChanged();
        }
    }

    QString title() const { return _title; }
    void setTitle(const QString &title) {
        if (_title != title) {
            _title = title;
            emit titleChanged();
        }
    }

    // Quiz games
    QVariantList quizGames() const {
        QVariantList list;
        for (QuizGame *game : _quizGames) {
            list << QVariant::fromValue(game);
        }
        return list;
    }

    void setQuizGames(const QVariantList &games) {
        _quizGames.clear();
        for (const QVariant &variant : games) {
            QuizGame *game = qobject_cast<QuizGame*>(variant.value<QObject*>());
            if (game) {
                _quizGames.append(game);
            }
        }
        emit quizGamesChanged();
    }

    // Memory games
    QVariantList memoryGames() const {
        QVariantList list;
        for (MemoryGame *game : _memoryGames) {
            list << QVariant::fromValue(game);
        }
        return list;
    }

    void setMemoryGames(const QVariantList &games) {
        _memoryGames.clear();
        for (const QVariant &variant : games) {
            MemoryGame *game = qobject_cast<MemoryGame*>(variant.value<QObject*>());
            if (game) {
                _memoryGames.append(game);
            }
        }
        emit memoryGamesChanged();
    }

    // Order games
    QVariantList orderGames() const {
        QVariantList list;
        for (OrderGame *game : _orderGames) {
            list << QVariant::fromValue(game);
        }
        return list;
    }

    void setOrderGames(const QVariantList &games) {
        _orderGames.clear();
        for (const QVariant &variant : games) {
            OrderGame *game = qobject_cast<OrderGame*>(variant.value<QObject*>());
            if (game) {
                _orderGames.append(game);
            }
        }
        emit orderGamesChanged();
    }

    // Selector games
    QVariantList selectorGames() const {
        QVariantList list;
        for (SelectorGame *game : _selectorGames) {
            list << QVariant::fromValue(game);
        }
        return list;
    }

    void setSelectorGames(const QVariantList &games) {
        _selectorGames.clear();
        for (const QVariant &variant : games) {
            SelectorGame *game = qobject_cast<SelectorGame*>(variant.value<QObject*>());
            if (game) {
                _selectorGames.append(game);
            }
        }
        emit selectorGamesChanged();
    }

    // Builder games
    QVariantList builderGames() const {
        QVariantList list;
        for (BuilderGame *game : _builderGames) {
            list << QVariant::fromValue(game);
        }
        return list;
    }

    void setBuilderGames(const QVariantList &games) {
        _builderGames.clear();
        for (const QVariant &variant : games) {
            BuilderGame *game = qobject_cast<BuilderGame*>(variant.value<QObject*>());
            if (game) {
                _builderGames.append(game);
            }
        }
        emit builderGamesChanged();
    }

    // Crosspuzzle games
    QVariantList crosspuzzleGames() const {
        QVariantList list;
        for (CrosspuzzleGame *game : _crosspuzzleGames) {
            list << QVariant::fromValue(game);
        }
        return list;
    }

    void setCrosspuzzleGames(const QVariantList &games) {
        _crosspuzzleGames.clear();
        for (const QVariant &variant : games) {
            CrosspuzzleGame *game = qobject_cast<CrosspuzzleGame*>(variant.value<QObject*>());
            if (game) {
                _crosspuzzleGames.append(game);
            }
        }
        emit crosspuzzleGamesChanged();
    }

    // Race games
    QVariantList raceGames() const {
        QVariantList list;
        for (RaceGame *game : _raceGames) {
            list << QVariant::fromValue(game);
        }
        return list;
    }

    void setRaceGames(const QVariantList &games) {
        _raceGames.clear();
        for (const QVariant &variant : games) {
            RaceGame *game = qobject_cast<RaceGame*>(variant.value<QObject*>());
            if (game) {
                _raceGames.append(game);
            }
        }
        emit raceGamesChanged();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["level"] = _level;
        obj["title"] = _title;

        QJsonArray gamesArray;

        // Add all game types to the games array - CRASH-SAFE with null checks
        for (const QuizGame *game : _quizGames) {
            if (game) { // Null check eklendi
                gamesArray.append(game->toJson());
            }
        }
        for (const MemoryGame *game : _memoryGames) {
            if (game) { // Null check eklendi
                gamesArray.append(game->toJson());
            }
        }
        for (const OrderGame *game : _orderGames) {
            if (game) { // Null check eklendi
                gamesArray.append(game->toJson());
            }
        }
        for (const SelectorGame *game : _selectorGames) {
            if (game) { // Null check eklendi
                gamesArray.append(game->toJson());
            }
        }
        for (const BuilderGame *game : _builderGames) {
            if (game) { // Null check eklendi
                gamesArray.append(game->toJson());
            }
        }
        for (const CrosspuzzleGame *game : _crosspuzzleGames) {
            if (game) { // Null check eklendi
                gamesArray.append(game->toJson());
            }
        }
        for (const RaceGame *game : _raceGames) {
            if (game) { // Null check eklendi
                gamesArray.append(game->toJson());
            }
        }

        obj["games"] = gamesArray;
        return obj;
    }

    void fromJson(const QJsonObject &obj) {
        setLevel(obj["level"].toInt());
        setTitle(obj["title"].toString());

        // Clear all existing games
        qDeleteAll(_quizGames);
        qDeleteAll(_memoryGames);
        qDeleteAll(_orderGames);
        qDeleteAll(_selectorGames);
        qDeleteAll(_builderGames);
        qDeleteAll(_crosspuzzleGames);
        qDeleteAll(_raceGames);

        _quizGames.clear();
        _memoryGames.clear();
        _orderGames.clear();
        _selectorGames.clear();
        _builderGames.clear();
        _crosspuzzleGames.clear();
        _raceGames.clear();

        QJsonArray gamesArray = obj["games"].toArray();
        for (const QJsonValue &value : gamesArray) {
            QJsonObject gameObj = value.toObject();
            QString gameType = gameObj["type"].toString();

            if (gameType == "quiz") {
                QuizGame *game = new QuizGame(this);
                game->fromJson(gameObj);
                _quizGames.append(game);
            } else if (gameType == "memory") {
                MemoryGame *game = new MemoryGame(this);
                game->fromJson(gameObj);
                _memoryGames.append(game);
            } else if (gameType == "order") {
                OrderGame *game = new OrderGame(this);
                game->fromJson(gameObj);
                _orderGames.append(game);
            } else if (gameType == "selector") {
                SelectorGame *game = new SelectorGame(this);
                game->fromJson(gameObj);
                _selectorGames.append(game);
            } else if (gameType == "builder") {
                BuilderGame *game = new BuilderGame(this);
                game->fromJson(gameObj);
                _builderGames.append(game);
            } else if (gameType == "crosspuzzle") {
                CrosspuzzleGame *game = new CrosspuzzleGame(this);
                game->fromJson(gameObj);
                _crosspuzzleGames.append(game);
            } else if (gameType == "race") {
                RaceGame *game = new RaceGame(this);
                game->fromJson(gameObj);
                _raceGames.append(game);
            }
        }

        emit quizGamesChanged();
        emit memoryGamesChanged();
        emit orderGamesChanged();
        emit selectorGamesChanged();
        emit builderGamesChanged();
        emit crosspuzzleGamesChanged();
        emit raceGamesChanged();
    }

signals:
    void levelChanged();
    void titleChanged();
    void quizGamesChanged();
    void memoryGamesChanged();
    void orderGamesChanged();
    void selectorGamesChanged();
    void builderGamesChanged();
    void crosspuzzleGamesChanged();
    void raceGamesChanged();
};

// Main GamesParser class
class GamesParser : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList levels READ levels WRITE setLevels NOTIFY levelsChanged)
    Q_PROPERTY(QString currentProjectName READ currentProjectName WRITE setCurrentProjectName NOTIFY currentProjectNameChanged)

public:
    explicit GamesParser(QObject *parent = nullptr);
    QString _bookDirectoryName;

    QVector<Level*> _levels;
    QString _currentProjectName;

    QVariantList levels() const {
        QVariantList list;
        for (Level *level : _levels) {
            list << QVariant::fromValue(level);
        }
        return list;
    }

    void setLevels(const QVariantList &levels) {
        _levels.clear();
        for (const QVariant &variant : levels) {
            Level *level = qobject_cast<Level*>(variant.value<QObject*>());
            if (level) {
                _levels.append(level);
            }
        }
        emit levelsChanged();
    }

    QString currentProjectName() const { return _currentProjectName; }
    void setCurrentProjectName(const QString &projectName) {
        if (_currentProjectName != projectName) {
            _currentProjectName = projectName;
            emit currentProjectNameChanged();
        }
    }

    // Load from JSON file
    Q_INVOKABLE bool loadFromFile(const QString &filePath);
    
    // Save to JSON file
    Q_INVOKABLE bool saveToFile();
    
    // Convert to JSON object
    QJsonObject toJson() const;
    
    // Load from JSON object
    void fromJson(const QJsonObject &obj);

    // Factory methods for creating games
    Q_INVOKABLE QuizGame* createQuizGame();
    Q_INVOKABLE MemoryGame* createMemoryGame();
    Q_INVOKABLE OrderGame* createOrderGame();
    Q_INVOKABLE SelectorGame* createSelectorGame();
    Q_INVOKABLE BuilderGame* createBuilderGame();
    Q_INVOKABLE CrosspuzzleGame* createCrosspuzzleGame();
    Q_INVOKABLE RaceGame* createRaceGame();
    Q_INVOKABLE Level* createLevel(int levelNumber, const QString &title);
    
    // Methods for managing quiz questions and answers
    Q_INVOKABLE QuizAnswer* createQuizAnswer(const QString &text = "", bool isCorrect = false);
    Q_INVOKABLE QuizQuestion* createQuizQuestion(const QString &question = "", const QString &image = "");
    Q_INVOKABLE void addQuestionToGame(QuizGame* game, QuizQuestion* question);
    Q_INVOKABLE void removeQuestionFromGame(QuizGame* game, int index);
    Q_INVOKABLE void addAnswerToQuestion(QuizQuestion* question, QuizAnswer* answer);
    Q_INVOKABLE void removeAnswerFromQuestion(QuizQuestion* question, int index);
    
    // Methods for managing memory questions
    Q_INVOKABLE MemoryQuestion* createMemoryQuestion(const QString &image = "", const QString &audio = "");
    Q_INVOKABLE void addQuestionToMemoryGame(MemoryGame* game, MemoryQuestion* question);
    Q_INVOKABLE void removeQuestionFromMemoryGame(MemoryGame* game, int index);
    
    // Methods for managing order questions
    Q_INVOKABLE OrderQuestion* createOrderQuestion(const QVariantList &words = QVariantList());
    Q_INVOKABLE void addQuestionToOrderGame(OrderGame* game, OrderQuestion* question);
    Q_INVOKABLE void removeQuestionFromOrderGame(OrderGame* game, int index);
    
    // Methods for managing selector questions and answers
    Q_INVOKABLE SelectorAnswer* createSelectorAnswer(const QString &text = "", const QString &image = "", bool isCorrect = false);
    Q_INVOKABLE SelectorQuestion* createSelectorQuestion(const QString &question = "", const QString &header = "", const QString &image = "", const QString &audio = "", const QString &video = "");
    Q_INVOKABLE void addQuestionToSelectorGame(SelectorGame* game, SelectorQuestion* question);
    Q_INVOKABLE void removeQuestionFromSelectorGame(SelectorGame* game, int index);
    Q_INVOKABLE void addAnswerToSelectorQuestion(SelectorQuestion* question, SelectorAnswer* answer);
    Q_INVOKABLE void removeAnswerFromSelectorQuestion(SelectorQuestion* question, int index);
    
    // Methods for managing builder questions
    Q_INVOKABLE BuilderQuestion* createBuilderQuestion(const QString &question = "", const QString &image = "", const QString &audio = "", const QString &video = "", const QVariantList &words = QVariantList());
    Q_INVOKABLE void addQuestionToBuilderGame(BuilderGame* game, BuilderQuestion* question);
    Q_INVOKABLE void removeQuestionFromBuilderGame(BuilderGame* game, int index);
    
    // Methods for managing crosspuzzle questions and answers
    Q_INVOKABLE CrosspuzzleAnswer* createCrosspuzzleAnswer(const QString &text = "");
    Q_INVOKABLE CrosspuzzleQuestion* createCrosspuzzleQuestion(const QString &question = "");
    Q_INVOKABLE void addQuestionToCrosspuzzleGame(CrosspuzzleGame* game, CrosspuzzleQuestion* question);
    Q_INVOKABLE void removeQuestionFromCrosspuzzleGame(CrosspuzzleGame* game, int index);
    Q_INVOKABLE void addAnswerToCrosspuzzleQuestion(CrosspuzzleQuestion* question, CrosspuzzleAnswer* answer);
    Q_INVOKABLE void removeAnswerFromCrosspuzzleQuestion(CrosspuzzleQuestion* question, int index);
    
    // Methods for managing race questions and answers
    Q_INVOKABLE RaceAnswer* createRaceAnswer(const QString &text = "", const QString &image = "", bool isCorrect = false);
    Q_INVOKABLE RaceQuestion* createRaceQuestion(const QString &question = "", const QString &image = "", const QString &audio = "");
    Q_INVOKABLE void addQuestionToRaceGame(RaceGame* game, RaceQuestion* question);
    Q_INVOKABLE void removeQuestionFromRaceGame(RaceGame* game, int index);
    Q_INVOKABLE void addAnswerToRaceQuestion(RaceQuestion* question, RaceAnswer* answer);
    Q_INVOKABLE void removeAnswerFromRaceQuestion(RaceQuestion* question, int index);
    
    // Add games to level methods
    Q_INVOKABLE void addQuizGameToLevel(Level* level, QuizGame* game);
    Q_INVOKABLE void addRaceGameToLevel(Level* level, RaceGame* game);
    Q_INVOKABLE void addMemoryGameToLevel(Level* level, MemoryGame* game);
    Q_INVOKABLE void addOrderGameToLevel(Level* level, OrderGame* game);
    Q_INVOKABLE void addSelectorGameToLevel(Level* level, SelectorGame* game);
    Q_INVOKABLE void addBuilderGameToLevel(Level* level, BuilderGame* game);
    Q_INVOKABLE void addCrosspuzzleGameToLevel(Level* level, CrosspuzzleGame* game);

signals:
    void levelsChanged();
    void currentProjectNameChanged();
};

#endif // GAMESPARSER_H 
