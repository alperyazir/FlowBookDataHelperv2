#ifndef CONFIGPARSER_H
#define CONFIGPARSER_H

#include <QQmlApplicationEngine>

#include <QRect>
#include <QString>
#include <QVector>
#include <QSet>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QObject>

#include <QCryptographicHash>
#include <QFile>
#include <QSaveFile>
#include <QFileInfo>
#include <QDateTime>
#include <QTextStream>
#include <QGuiApplication>
#include <QDir>
#include <QMutex>
#include <QMutexLocker>
#include <QException>
#include <QRandomGenerator>


struct CircleExtra : public QObject {
    Q_OBJECT
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    Q_PROPERTY(QString type READ type WRITE setType NOTIFY typeChanged)

public:
    explicit CircleExtra(QObject *parent = nullptr) :
        QObject(parent), _coords(), _text(), _type() {}

    QRect _coords;
    QString _text;
    QString _type;

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {
            _coords = coords;
            emit coordsChanged();
        }
    }

    QString text() const { return _text; }
    void setText(const QString &text) {
        if (_text != text) {
            _text = text;
            emit textChanged();
        }
    }

    QString type() const { return _type; }
    void setType(const QString &type) {
        if (_type != type) {
            _type = type;
            emit typeChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject circleExtraObj;
        
        if (!_type.isEmpty()) {
            circleExtraObj["type"] = _type;
        }
        
        if (!_text.isEmpty()) {
            circleExtraObj["text"] = _text;
        }

        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            circleExtraObj["coords"] = coordsObj;
        }

        return circleExtraObj;
    }

signals:
    void coordsChanged();
    void textChanged();
    void typeChanged();
};

struct Letter : public QObject {
    Q_OBJECT
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)

public:
    explicit Letter(QObject *parent = nullptr) :
        QObject(parent), _coords(), _text() {}

    QRect _coords;
    QString _text;

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {
            _coords = coords;
            emit coordsChanged();
        }
    }

    QString text() const { return _text; }
    void setText(const QString &text) {
        if (_text != text) {
            _text = text;
            emit textChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject letterObj;
        
        if (!_text.isEmpty()) {
            letterObj["text"] = _text;
        }

        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            letterObj["coords"] = coordsObj;
        }

        return letterObj;
    }

signals:
    void coordsChanged();
    void textChanged();
};

struct Answer : public QObject {
    Q_OBJECT
    Q_PROPERTY(int no READ no WRITE setNo NOTIFY noChanged)
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    Q_PROPERTY(bool isCorrect READ isCorrect WRITE setIsCorrect NOTIFY isCorrectChanged)
    Q_PROPERTY(QRect sourceCoords READ sourceCoords WRITE setSourceCoords NOTIFY sourceCoordsChanged)
    Q_PROPERTY(QString sourceText READ sourceText WRITE setSourceText NOTIFY sourceTextChanged)
    Q_PROPERTY(bool diagonal READ diagonal WRITE setDiagonal NOTIFY diagonalChanged)
    Q_PROPERTY(QString diagonalSide READ diagonalSide WRITE setDiagonalSide NOTIFY diagonalSideChanged)
    Q_PROPERTY(QString realAnswer READ realAnswer WRITE setRealAnswer NOTIFY realAnswerChanged)
    Q_PROPERTY(qreal rotation READ rotation WRITE setRotation NOTIFY rotationChanged)
    Q_PROPERTY(QVariantList letters READ letters WRITE setLetters NOTIFY lettersChanged)
    Q_PROPERTY(QVariantList group READ group WRITE setGroup NOTIFY groupChanged)
    Q_PROPERTY(bool isTrueSection READ isTrueSection WRITE setIsTrueSection NOTIFY isTrueSectionChanged)

    // Yeni eklenen özellikler
    Q_PROPERTY(QString color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(bool isRound READ isRound WRITE setIsRound NOTIFY isRoundChanged)
    Q_PROPERTY(double opacity READ opacity WRITE setOpacity NOTIFY opacityChanged)
    Q_PROPERTY(QRect rectBegin READ rectBegin WRITE setRectBegin NOTIFY rectBeginChanged)
    Q_PROPERTY(QRect rectEnd READ rectEnd WRITE setRectEnd NOTIFY rectEndChanged)
    Q_PROPERTY(QPoint lineBegin READ lineBegin WRITE setLineBegin NOTIFY lineBeginChanged)
    Q_PROPERTY(QPoint lineEnd READ lineEnd WRITE setLineEnd NOTIFY lineEndChanged)
    Q_PROPERTY(QString textColor READ textColor WRITE setTextColor NOTIFY textColorChanged)
    Q_PROPERTY(bool isTextBold READ isTextBold WRITE setIsTextBold NOTIFY isTextBoldChanged)
    // Fill-with-color: optional image shown clipped inside the shape
    // (rect/round) instead of the flat color fill.
    Q_PROPERTY(QString imagePath READ imagePath WRITE setImagePath NOTIFY imagePathChanged)

public:
    explicit Answer(QObject *parent = nullptr) :
        QObject(parent), _no(0), _isCorrect(false), _diagonal(false),
        _rotation(0.0), _isTrueSection(false),
        _isRound(false), _opacity(1.0), _isTextBold(false) {
    }

    int _no;
    QRect _coords;
    QString _text;
    bool _isCorrect;
    QRect _sourceCoords;
    QString _sourceText;
    bool _diagonal;
    QString _diagonalSide;
    QString _realAnswer;
    qreal _rotation;
    QVector<Letter*> _letters;
    QVector<QString> _group;
    bool _isTrueSection;

    // Yeni değişkenler
    QString _color;
    bool _isRound;
    double _opacity;
    QRect _rectBegin;
    QRect _rectEnd;
    QPoint _lineBegin;
    QPoint _lineEnd;
    QString _textColor;
    bool _isTextBold;
    QString _imagePath;

    // Mevcut getter/setter'lar...
    int no() const { return _no; }
    void setNo(int no) {
        if (_no != no) {
            _no = no;
            emit noChanged();
        }
    }

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {

            _coords = coords;
            emit coordsChanged();
        }
    }

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

    QRect sourceCoords() const { return _sourceCoords; }
    void setSourceCoords(const QRect &sourceCoords) {
        if (_sourceCoords != sourceCoords) {
            _sourceCoords = sourceCoords;
            emit sourceCoordsChanged();
        }
    }

    QString sourceText() const { return _sourceText; }
    void setSourceText(const QString &sourceText) {
        if (_sourceText != sourceText) {
            _sourceText = sourceText;
            emit sourceTextChanged();
        }
    }

    bool diagonal() const { return _diagonal; }
    void setDiagonal(bool diagonal) {
        if (_diagonal != diagonal) {
            _diagonal = diagonal;
            emit diagonalChanged();
        }
    }

    QString diagonalSide() const { return _diagonalSide; }
    void setDiagonalSide(const QString &diagonalSide) {
        if (_diagonalSide != diagonalSide) {
            _diagonalSide = diagonalSide;
            emit diagonalSideChanged();
        }
    }

    QString realAnswer() const { return _realAnswer; }
    void setRealAnswer(const QString &realAnswer) {
        if (_realAnswer != realAnswer) {
            _realAnswer = realAnswer;
            emit realAnswerChanged();
        }
    }

    qreal rotation() const { return _rotation; }
    void setRotation(qreal rotation) {
        if (!qFuzzyCompare(_rotation, rotation)) {
            _rotation = rotation;
            emit rotationChanged();
        }
    }

    QVariantList letters() const {
        QVariantList l;
        for (Letter *a : _letters) {
            l << QVariant::fromValue(a);
        }
        return l;
    }
    void setLetters(const QVariantList &letters) {
        _letters.clear();
        for (const QVariant &l : letters) {
            Letter *letter = qobject_cast<Letter*>(l.value<QObject*>());
            if (letter) {
                _letters.append(letter);
            }
        }
        emit lettersChanged();
    }

    QVariantList group() const {
        QVariantList l;
        for (const QString &s : _group) {
            l << s;
        }
        return l;
    }
    void setGroup(const QVariantList &group) {
        _group.clear();
        for (const QVariant &g : group) {
            if (g.canConvert<QString>()) {
                _group.append(g.toString());
            }
        }
        emit groupChanged();
    }

    bool isTrueSection() const { return _isTrueSection; }
    void setIsTrueSection(bool isTrueSection) {
        if (_isTrueSection != isTrueSection) {
            _isTrueSection = isTrueSection;
            emit isTrueSectionChanged();
        }
    }

    // Yeni eklenen getter/setter'lar
    QString color() const { return _color; }
    void setColor(const QString &color) {
        if (_color != color) {
            _color = color;
            emit colorChanged();
        }
    }

    bool isRound() const { return _isRound; }
    void setIsRound(bool isRound) {
        if (_isRound != isRound) {
            _isRound = isRound;
            emit isRoundChanged();
        }
    }

    double opacity() const { return _opacity; }
    void setOpacity(double opacity) {
        if (!qFuzzyCompare(_opacity, opacity)) {
            _opacity = opacity;
            emit opacityChanged();
        }
    }

    QRect rectBegin() const { return _rectBegin; }
    void setRectBegin(const QRect &rectBegin) {
        if (_rectBegin != rectBegin) {
            _rectBegin = rectBegin;
            emit rectBeginChanged();
        }
    }

    QRect rectEnd() const { return _rectEnd; }
    void setRectEnd(const QRect &rectEnd) {
        if (_rectEnd != rectEnd) {
            _rectEnd = rectEnd;
            emit rectEndChanged();
        }
    }

    QPoint lineBegin() const { return _lineBegin; }
    void setLineBegin(const QPoint &lineBegin) {
        if (_lineBegin != lineBegin) {
            _lineBegin = lineBegin;
            emit lineBeginChanged();
        }
    }

    QPoint lineEnd() const { return _lineEnd; }
    void setLineEnd(const QPoint &lineEnd) {
        if (_lineEnd != lineEnd) {
            _lineEnd = lineEnd;
            emit lineEndChanged();
        }
    }


    QString textColor() const { return _textColor; }
    void setTextColor(const QString &textColor) {
        if (_textColor != textColor) {
            _textColor = textColor;
            emit textColorChanged();
        }
    }

    bool isTextBold() const { return _isTextBold; }
    void setIsTextBold(const bool &isTextBold) {
        if (_isTextBold != isTextBold) {
            _isTextBold = isTextBold;
            emit isTextBoldChanged();
        }
    }

    QString imagePath() const { return _imagePath; }
    void setImagePath(const QString &imagePath) {
        if (_imagePath != imagePath) {
            _imagePath = imagePath;
            emit imagePathChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject answerObj;

        if (!_text.isEmpty()) {
            answerObj["text"] = _text;
        }

        if (_no != 0) {
            answerObj["no"] = _no;
        }

        if (_diagonal) {
            answerObj["diagonal"] = _diagonal;
        }

        if (!_diagonalSide.isEmpty()) {
            answerObj["diagonal_side"] = _diagonalSide;
        }

        if (_isCorrect) {
            answerObj["isCorrect"] = _isCorrect;
        }

        if (!_realAnswer.isEmpty()) {
            answerObj["real_answer"] = _realAnswer;
        }

        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            answerObj["coords"] = coordsObj;
        }

        if (!_sourceCoords.isNull() && _sourceCoords.isValid()) {
            QJsonObject sourceCoordsObj;
            sourceCoordsObj["x"] = _sourceCoords.x();
            sourceCoordsObj["y"] = _sourceCoords.y();
            sourceCoordsObj["w"] = _sourceCoords.width();
            sourceCoordsObj["h"] = _sourceCoords.height();
            answerObj["sourceCoords"] = sourceCoordsObj;
        }

        if (!_sourceText.isEmpty()) {
            answerObj["sourceText"] = _sourceText;
        }

        if (!qFuzzyIsNull(_rotation)) {
            answerObj["rotation"] = _rotation;
        }

        if (!_letters.isEmpty()) {
            QJsonArray lettersArray;
            for (const Letter *letter : _letters) {
                if (letter) { // Null check eklendi
                    lettersArray.append(letter->toJson());
                }
            }
            answerObj["letters"] = lettersArray;
        }

        if (!_group.isEmpty()) {
            QJsonArray groupArray;
            for (const QString &group : _group) {
                groupArray.append(group);
            }
            answerObj["group"] = groupArray;
        }

        // Yeni özellikler JSON'a eklendi
        if (!_color.isEmpty()) {
            answerObj["color"] = _color;
        }

        if (_isRound) {
            answerObj["isRound"] = _isRound;
        }

        if (!qFuzzyIsNull(_opacity)) {
            answerObj["opacity"] = _opacity;
        }

        if (!_rectBegin.isNull() && _rectBegin.isValid()) {
            QJsonObject rectBeginObj;
            rectBeginObj["x"] = _rectBegin.x();
            rectBeginObj["y"] = _rectBegin.y();
            rectBeginObj["w"] = _rectBegin.width();
            rectBeginObj["h"] = _rectBegin.height();
            answerObj["rectBegin"] = rectBeginObj;
        }

        if (!_rectEnd.isNull() && _rectEnd.isValid()) {
            QJsonObject rectEndObj;
            rectEndObj["x"] = _rectEnd.x();
            rectEndObj["y"] = _rectEnd.y();
            rectEndObj["w"] = _rectEnd.width();
            rectEndObj["h"] = _rectEnd.height();
            answerObj["rectEnd"] = rectEndObj;
        }

        if (!_lineBegin.isNull()) {
            QJsonObject lineBeginObj;
            lineBeginObj["x"] = _lineBegin.x();
            lineBeginObj["y"] = _lineBegin.y();
            answerObj["lineBegin"] = lineBeginObj;
        }

        if (!_lineEnd.isNull()) {
            QJsonObject lineEndObj;
            lineEndObj["x"] = _lineEnd.x();
            lineEndObj["y"] = _lineEnd.y();
            answerObj["lineEnd"] = lineEndObj;
        }

        if (!_textColor.isEmpty()) {
            answerObj["text_color"] = _textColor;
        }
        if (_isTextBold) {
            answerObj["is_text_bold"] = _isTextBold;
        }

        if (!_imagePath.isEmpty()) {
            answerObj["image_path"] = _imagePath;
        }


        return answerObj;
    }

signals:
    void noChanged();
    void coordsChanged();
    void textChanged();
    void isCorrectChanged();
    void sourceCoordsChanged();
    void sourceTextChanged();
    void diagonalChanged();
    void diagonalSideChanged();
    void realAnswerChanged();
    void rotationChanged();
    void lettersChanged();
    void groupChanged();
    void isTrueSectionChanged();

    // Yeni sinyaller
    void colorChanged();
    void isRoundChanged();
    void opacityChanged();
    void rectBeginChanged();
    void rectEndChanged();
    void lineBeginChanged();
    void lineEndChanged();
    void textColorChanged();
    void isTextBoldChanged();
    void imagePathChanged();
};

struct MatchWord : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString word READ word WRITE setWord NOTIFY wordChanged)
    Q_PROPERTY(QString imagePath READ imagePath WRITE setImagePath NOTIFY imagePathChanged)

public:
    explicit MatchWord(QObject *parent = nullptr) : QObject(parent), _word(), _imagePath() {}

    QString _word;
    QString _imagePath;

    QString word() const { return _word; }
    void setWord(const QString &word) {
        if (_word != word) {
            _word = word;
            emit wordChanged();
        }
    }

    QString imagePath() const { return _imagePath; }
    void setImagePath(const QString &imagePath) {
        if (_imagePath != imagePath) {
            _imagePath = imagePath;
            emit imagePathChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject matchWordObj;
        
        if (!_word.isEmpty()) {
            matchWordObj["word"] = _word;
        }
        
        if (!_imagePath.isEmpty()) {
            matchWordObj["image_path"] = _imagePath;
        }
        
        return matchWordObj;
    }
signals:
    void wordChanged();
    void imagePathChanged();
};

struct Sentences : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString sentence READ sentence WRITE setSentence NOTIFY sentenceChanged)
    Q_PROPERTY(QString sentenceAfter READ sentenceAfter WRITE setSentenceAfter NOTIFY sentenceAfterChanged)
    Q_PROPERTY(QString word READ word WRITE setWord NOTIFY wordChanged)
    Q_PROPERTY(QString imagePath READ imagePath WRITE setImagePath NOTIFY imagePathChanged)

public:
    explicit Sentences(QObject *parent = nullptr) : QObject(parent), _sentence(), _sentenceAfter(), _word(), _imagePath() {}

    QString _sentence;
    QString _sentenceAfter;
    QString _word;
    QString _imagePath;

    QString sentence() const { return _sentence; }
    void setSentence(const QString &sentence) {
        if (_sentence != sentence) {
            _sentence = sentence;
            emit sentenceChanged();
        }
    }

    QString sentenceAfter() const { return _sentenceAfter; }
    void setSentenceAfter(const QString &sentenceAfter) {
        if (_sentenceAfter != sentenceAfter) {
            _sentenceAfter = sentenceAfter;
            emit sentenceAfterChanged();
        }
    }

    QString word() const { return _word; }
    void setWord(const QString &word) {
        if (_word != word) {
            _word = word;
            emit wordChanged();
        }
    }

    QString imagePath() const { return _imagePath; }
    void setImagePath(const QString &imagePath) {
        if (_imagePath != imagePath) {
            _imagePath = imagePath;
            emit imagePathChanged();
        }
    }
    QJsonObject toJson() const {
        QJsonObject sentenceObj;
        
        if (!_sentence.isEmpty()) {
            sentenceObj["sentence"] = _sentence;
        }
        
        if (!_sentenceAfter.isEmpty()) {
            sentenceObj["sentence_after"] = _sentenceAfter;
        }
        
        if (!_word.isEmpty()) {
            sentenceObj["word"] = _word;
        }
        
        if (!_imagePath.isEmpty()) {
            sentenceObj["image_path"] = _imagePath;
        }
        
        return sentenceObj;
    }


signals:
    void sentenceChanged();
    void sentenceAfterChanged();
    void wordChanged();
    void imagePathChanged();
};

struct Activity : public QObject {
    Q_OBJECT
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)
    Q_PROPERTY(QRect imageCoords READ imageCoords WRITE setImageCoords NOTIFY imageCoordsChanged)
    Q_PROPERTY(QString type READ type WRITE setType NOTIFY typeChanged)
    Q_PROPERTY(QString sectionPath READ sectionPath WRITE setSectionPath NOTIFY sectionPathChanged)
    Q_PROPERTY(QVariantList answers READ answers WRITE setAnswers NOTIFY answersChanged)
    Q_PROPERTY(QVariantList words READ words WRITE setWords NOTIFY wordsChanged)
    Q_PROPERTY(QVariantList sentences READ sentences WRITE setSentences NOTIFY sentencesChanged)
    Q_PROPERTY(QVariantList matchWord READ matchWord WRITE setMatchWord NOTIFY matchWordChanged)
    Q_PROPERTY(QString headerText READ headerText WRITE setHeaderText NOTIFY headerTextChanged)
    Q_PROPERTY(int circleCount READ circleCount WRITE setCircleCount NOTIFY circleCountChanged)
    Q_PROPERTY(int markCount READ markCount WRITE setMarkCount NOTIFY markCountChanged)
    Q_PROPERTY(bool isTrueFalseEnabled READ isTrueFalseEnabled WRITE setIsTrueFalseEnabled NOTIFY isTrueFalseEnabledChanged)
    Q_PROPERTY(bool isTextOnLeft READ isTextOnLeft WRITE setIsTextOnLeft NOTIFY isTextOnLeftChanged)
    Q_PROPERTY(int textFontSize READ textFontSize WRITE setTextFontSize NOTIFY textFontSizeChanged)
    Q_PROPERTY(QVariantList circleExtra READ circleExtra WRITE setCircleExtra NOTIFY circleExtraChanged)

public:
    explicit Activity(QObject *parent = nullptr) :
        QObject(parent),
        _circleCount(2),
        _markCount(2),
        _isTrueFalseEnabled(false),
        _isTextOnLeft(false),
        _textFontSize(0) {}

    QRect _coords;
    QRect _image_coords;   // page-PNG region the cropped activity image covers
    QString _type;
    QString _section_path;
    QVector<Answer*> _answers;
    QVector<QString> _words;
    QVector<Sentences*> _sentences;
    QVector<MatchWord*> _matchWord;
    QString _header_text;
    int _circleCount;
    int _markCount;
    bool _isTrueFalseEnabled;
    bool _isTextOnLeft;
    int _textFontSize;
    QVector<CircleExtra*> _circleExtra;

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {
            _coords = coords;
            emit coordsChanged();
        }
    }

    QRect imageCoords() const { return _image_coords; }
    void setImageCoords(const QRect &imageCoords) {
        if (_image_coords != imageCoords) {
            _image_coords = imageCoords;
            emit imageCoordsChanged();
        }
    }

    QString type() const { return _type; }
    void setType(const QString &type) {
        if (_type != type) {
            _type = type;
            emit typeChanged();
        }
    }

    QString sectionPath() const { return _section_path; }
    void setSectionPath(const QString &sectionPath) {
        if (_section_path != sectionPath) {
            _section_path = sectionPath;
            emit sectionPathChanged();
        }
    }

    QVariantList answers() const {
        QVariantList l;
        for (Answer *a : _answers) {
            l << QVariant::fromValue(a);
        }
        return l;
    }
    void setAnswers(const QVariantList &answers) {
        // CRASH-SAFE: Eski objeler için memory cleanup
        for (Answer *answer : _answers) {
            if (answer) {
                answer->deleteLater();
            }
        }
        _answers.clear();
        
        for (const QVariant &a : answers) {
            Answer *answer = qobject_cast<Answer*>(a.value<QObject*>());
            if (answer) {
                _answers.append(answer);
            }
        }
        emit answersChanged();
    }

    Q_INVOKABLE void createNewAnswer(int x, int y, int w, int h, const QString &text = "" ) {
        try {
            Answer *answer = new Answer(this); // Parent set edildi
            answer->setCoords(QRect(x,y,w,h));
            answer->setText(text);

            _answers.push_back(answer);
            emit answersChanged();
        } catch (...) {
            qCritical("Exception in createNewAnswer");
        }
    }

    Q_INVOKABLE void removeAnswer(int index) {
        if (index >= 0 && index < _answers.size()) {
            Answer *answer = _answers[index];
            _answers.erase(_answers.begin() + index);
            if (answer) {
                answer->deleteLater(); // Qt-safe deletion
            }
            emit answersChanged();
        }
    }

    // Reorder an answer zone WITHIN this activity, so a reviewer can fix the
    // order the reader reveals them in. Mirror of Page/Section moveAnswer.
    Q_INVOKABLE void moveAnswer(int from, int to) {
        if (from < 0 || from >= _answers.size()) return;
        if (to < 0 || to >= _answers.size()) return;
        if (from == to) return;
        Answer *a = _answers.takeAt(from);
        _answers.insert(to, a);
        emit answersChanged();
    }

    Q_INVOKABLE void addNewWord(const QString &word = "") {
        _words.push_back(word);
        emit wordsChanged();
    }

    Q_INVOKABLE void removeWord(int index) {
        if (index >= 0 && index < _words.size()) {
            _words.erase(_words.begin() + index);
            emit wordsChanged();
        }

    }

    QVariantList words() const {
        QVariantList l;
        for (const QString &s : _words) {
            l << s;
        }
        return l;
    }
    void setWords(const QVariantList &words) {
        _words.clear();
        for (const QVariant &w : words) {
            if (w.canConvert<QString>()) {
                _words.append(w.toString());
            }
        }
        emit wordsChanged();
    }

    QVariantList matchWord() const {
        QVariantList l;
        for (MatchWord* s : _matchWord) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setMatchWord(const QVariantList &matchWords) {
        _matchWord.clear();
        for (const QVariant &mw : matchWords) {
            MatchWord *matchWord = qobject_cast<MatchWord*>(mw.value<QObject*>());
            if (matchWord) {
                _matchWord.append(matchWord);
            }
        }
        emit matchWordChanged();
    }

    Q_INVOKABLE void createMatchWord(const QString &word, const QString &imagePath) {
        MatchWord *matchWord = new MatchWord(this); // Parent set edildi
        matchWord->setWord(word);
        matchWord->setImagePath(imagePath);

        _matchWord.push_back(matchWord);
        emit matchWordChanged();
    }

    Q_INVOKABLE void removeMatchWord(int index) {
        if (index >= 0 && index < _matchWord.size()) {
            MatchWord *word = _matchWord[index];
            _matchWord.erase(_matchWord.begin() + index);
            if (word) {
                word->deleteLater(); // Qt-safe deletion
            }
            emit matchWordChanged();
        }
    }

    QVariantList sentences() const {
        QVariantList l;
        for (Sentences* s : _sentences) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setSentences(const QVariantList &sentences) {
        _sentences.clear();
        for (const QVariant &s : sentences) {
            Sentences *sentence = qobject_cast<Sentences*>(s.value<QObject*>());
            if (sentence) {
                _sentences.append(sentence);
            }
        }
        emit sentencesChanged();
    }

    Q_INVOKABLE void createSentences(const QString &word, const QString &sentences, const QString &imagePath) {
        Sentences *sentence = new Sentences(this); // Parent set edildi
        sentence->setWord(word);
        sentence->setImagePath(imagePath);
        sentence->setSentence(sentences);

        _sentences.push_back(sentence);
        emit sentencesChanged();
    }

    Q_INVOKABLE void removeSentences(int index) {
        if (index >= 0 && index < _sentences.size()) {
            Sentences *sentence = _sentences[index];
            _sentences.erase(_sentences.begin() + index);
            if (sentence) {
                sentence->deleteLater(); // Qt-safe deletion
            }
            emit sentencesChanged();
        }
    }

    QVariantList circleExtra() const {
        QVariantList l;
        for (CircleExtra *c : _circleExtra) {
            l << QVariant::fromValue(c);
        }
        return l;
    }
    void setCircleExtra(const QVariantList &circleExtras) {
        _circleExtra.clear();
        for (const QVariant &ce : circleExtras) {
            CircleExtra *circleExtra = qobject_cast<CircleExtra*>(ce.value<QObject*>());
            if (circleExtra) {
                _circleExtra.append(circleExtra);
            }
        }
        emit circleExtraChanged();
    }

    QString headerText() const { return _header_text; }
    void setHeaderText(const QString &headerText) {
        if (_header_text != headerText) {
            _header_text = headerText;
            emit headerTextChanged();
        }
    }

    int circleCount() const { return _circleCount; }
    void setCircleCount(int circleCount) {
        if (_circleCount != circleCount) {
            _circleCount = circleCount;
            emit circleCountChanged();
        }
    }

    int markCount() const { return _markCount; }
    void setMarkCount(int markCount) {
        if (_markCount != markCount) {
            _markCount = markCount;
            emit markCountChanged();
        }
    }

    bool isTrueFalseEnabled() const { return _isTrueFalseEnabled; }
    void setIsTrueFalseEnabled(bool isTrueFalseEnabled) {
        if (_isTrueFalseEnabled != isTrueFalseEnabled) {
            _isTrueFalseEnabled = isTrueFalseEnabled;
            emit isTrueFalseEnabledChanged();
        }
    }

    bool isTextOnLeft() const { return _isTextOnLeft; }
    void setIsTextOnLeft(bool isTextOnLeft) {
        if (_isTextOnLeft != isTextOnLeft) {
            _isTextOnLeft = isTextOnLeft;
            emit isTextOnLeftChanged();
        }
    }

    int textFontSize() const { return _textFontSize; }
    void setTextFontSize(int textFontSize) {
        if (_textFontSize != textFontSize) {
            _textFontSize = textFontSize;
            emit textFontSizeChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject activityObj;
        
        if (!_type.isEmpty()) {
            activityObj["type"] = _type;
        }
        
        if (!_section_path.isEmpty()) {
            activityObj["section_path"] = _section_path;
        }
        
        if (!_header_text.isEmpty()) {
            activityObj["headerText"] = _header_text;
        }
        
        if (_circleCount != 2) {
            activityObj["circleCount"] = _circleCount;
        }
        
        if (_markCount != 2) {
            activityObj["markCount"] = _markCount;
        }
        
        if (_isTrueFalseEnabled) {
            activityObj["isTrueFalseEnabled"] = _isTrueFalseEnabled;
        }
        
        if (_isTextOnLeft) {
            activityObj["isTextOnLeft"] = _isTextOnLeft;
        }
        
        if (_textFontSize != 0) {
            activityObj["textFontSize"] = _textFontSize;
        }

        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            activityObj["coords"] = coordsObj;
        }

        if (!_image_coords.isNull() && _image_coords.isValid()) {
            QJsonObject imageCoordsObj;
            imageCoordsObj["x"] = _image_coords.x();
            imageCoordsObj["y"] = _image_coords.y();
            imageCoordsObj["w"] = _image_coords.width();
            imageCoordsObj["h"] = _image_coords.height();
            activityObj["image_coords"] = imageCoordsObj;
        }

        if (!_answers.isEmpty()) {
            QJsonArray answersArray;
            for (const Answer *answer : _answers) {
                if (answer) { // Null check eklendi
                    answersArray.append(answer->toJson());
                }
            }
            activityObj["answer"] = answersArray;
        }

        if (!_sentences.isEmpty()) {
            QJsonArray sentencesArray;
            for (const Sentences *sentence : _sentences) {
                if (sentence) { // Null check eklendi
                    sentencesArray.append(sentence->toJson());
                }
            }
            activityObj["sentences"] = sentencesArray;
        }

        if (!_words.isEmpty()) {
            // NOTE: toJson() is deterministic on purpose — it is also the basis
            // for unsaved-change detection (hash compare). Drag&drop word pools
            // must ship shuffled so their saved order isn't the answer key, but
            // that shuffle is applied only to the bytes written to disk (see
            // BookSet::shuffleWordPoolsForDisk), never here. Otherwise every
            // serialization would differ and the app would always look "dirty".
            QJsonArray wordsArray;
            for (const QString &word : _words) {
                wordsArray.append(word);
            }
            activityObj["words"] = wordsArray;
        }

        if (!_matchWord.isEmpty()) {
            QJsonArray matchWordsArray;
            for (const MatchWord *matchWord : _matchWord) {
                if (matchWord) { // Null check eklendi
                    matchWordsArray.append(matchWord->toJson());
                }
            }
            activityObj["match_words"] = matchWordsArray;
        }

        if (!_circleExtra.isEmpty()) {
            QJsonArray circleExtraArray;
            for (const CircleExtra *circleExtra : _circleExtra) {
                if (circleExtra) { // Null check eklendi
                    circleExtraArray.append(circleExtra->toJson());
                }
            }
            activityObj["circle_extra"] = circleExtraArray;
        }

        return activityObj;
    }

signals:
    void coordsChanged();
    void imageCoordsChanged();
    void typeChanged();
    void sectionPathChanged();
    void answersChanged();
    void wordsChanged();
    void sentencesChanged();
    void matchWordChanged();
    void headerTextChanged();
    void circleCountChanged();
    void markCountChanged();
    void isTrueFalseEnabledChanged();
    void isTextOnLeftChanged();
    void textFontSizeChanged();
    void circleExtraChanged();
};

struct AudioExtra : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)

public:
    explicit AudioExtra(QObject *parent = nullptr) : QObject(parent), _path(), _coords() {}

    QString _path;
    QRect _coords;

    QString path() const { return _path; }
    void setPath(const QString &path) {
        if (_path != path) {
            _path = path;
            emit pathChanged();
        }
    }

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {
            _coords = coords;
            emit coordsChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject audioExtraObj;
        
        if (!_path.isEmpty()) {
            audioExtraObj["path"] = _path;
        }
        
        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            audioExtraObj["coords"] = coordsObj;
        }
        
        return audioExtraObj;
    }

signals:
    void pathChanged();
    void coordsChanged();
};

struct Magnifier : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString sectionPath READ sectionPath WRITE setSectionPath NOTIFY sectionPathChanged)
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)

public:
    explicit Magnifier(QObject *parent = nullptr) :
        QObject(parent), _sectionPath(), _coords() {}

    QString _sectionPath;
    QRect _coords;

    QString sectionPath() const { return _sectionPath; }
    void setSectionPath(const QString &sectionPath) {
        if (_sectionPath != sectionPath) {
            _sectionPath = sectionPath;
            emit sectionPathChanged();
        }
    }

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {
            _coords = coords;
            emit coordsChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject magnifierObj;
        
        if (!_sectionPath.isEmpty()) {
            magnifierObj["section_path"] = _sectionPath;
        }
        
        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            magnifierObj["coords"] = coordsObj;
        }
        
        return magnifierObj;
    }

signals:
    void sectionPathChanged();
    void coordsChanged();
};

struct FreeTextFields : public QObject {
    Q_OBJECT
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)

public:
    explicit FreeTextFields(QObject *parent = nullptr) :
        QObject(parent), _coords() {}

    QRect _coords;

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {
            _coords = coords;
            emit coordsChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject freeTextFieldObj;
        
        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            freeTextFieldObj["coords"] = coordsObj;
        }
        
        return freeTextFieldObj;
    }

signals:
    void coordsChanged();
};

struct Subtitles : public QObject {
    Q_OBJECT
    Q_PROPERTY(int id READ id WRITE setId NOTIFY idChanged)
    Q_PROPERTY(qreal startTime READ startTime WRITE setStartTime NOTIFY startTimeChanged)
    Q_PROPERTY(qreal endTime READ endTime WRITE setEndTime NOTIFY endTimeChanged)
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged)

public:
    explicit Subtitles(QObject *parent = nullptr) :
        QObject(parent), _id(0), _startTime(0), _endTime(0), _subtitle() {}

    int _id;
    qreal _startTime;
    qreal _endTime;
    QString _subtitle;

    int id() const { return _id; }
    void setId(int id) {
        if (_id != id) {
            _id = id;
            emit idChanged();
        }
    }

    qreal startTime() const { return _startTime; }
    void setStartTime(qreal startTime) {
        if (!qFuzzyCompare(_startTime, startTime)) {
            _startTime = startTime;
            emit startTimeChanged();
        }
    }

    qreal endTime() const { return _endTime; }
    void setEndTime(qreal endTime) {
        if (!qFuzzyCompare(_endTime, endTime)) {
            _endTime = endTime;
            emit endTimeChanged();
        }
    }

    QString subtitle() const { return _subtitle; }
    void setSubtitle(const QString &subtitle) {
        if (_subtitle != subtitle) {
            _subtitle = subtitle;
            emit subtitleChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject subtitleObj;
        
        if (_id != 0) {
            subtitleObj["id"] = _id;
        }
        
        if (!qFuzzyIsNull(_startTime)) {
            subtitleObj["startTime"] = _startTime;
        }
        
        if (!qFuzzyIsNull(_endTime)) {
            subtitleObj["endTime"] = _endTime;
        }
        
        if (!_subtitle.isEmpty()) {
            subtitleObj["subtitle"] = _subtitle;
        }
        
        return subtitleObj;
    }

signals:
    void idChanged();
    void startTimeChanged();
    void endTimeChanged();
    void subtitleChanged();
};

struct Video : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QVariantList subtitles READ subtitles WRITE setSubtitles NOTIFY subtitlesChanged)

public:
    explicit Video(QObject *parent = nullptr) : QObject(parent), _path() {}

    QString _path;
    QVector<Subtitles*> _subtitles;

    QString path() const { return _path; }
    void setPath(const QString &path) {
        if (_path != path) {
            _path = path;
            emit pathChanged();
        }
    }

    QVariantList subtitles() const {
        QVariantList l;
        for (Subtitles *s : _subtitles) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setSubtitles(const QVariantList &subtitles) {
        _subtitles.clear();
        for (const QVariant &s : subtitles) {
            Subtitles *subtitle = qobject_cast<Subtitles*>(s.value<QObject*>());
            if (subtitle) {
                _subtitles.append(subtitle);
            }
        }
        emit subtitlesChanged();
    }

    QJsonObject toJson() const {
        QJsonObject videoObj;
        
        if (!_path.isEmpty()) {
            videoObj["path"] = _path;
        }

        if (!_subtitles.isEmpty()) {
            QJsonArray subtitlesArray;
            for (const Subtitles *subtitle : _subtitles) {
                if (subtitle) { // Null check eklendi
                    subtitlesArray.append(subtitle->toJson());
                }
            }
            videoObj["subtitles"] = subtitlesArray;
        }

        return videoObj;
    }

signals:
    void pathChanged();
    void subtitlesChanged();
};

struct Section : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    Q_PROPERTY(QString type READ type WRITE setType NOTIFY typeChanged)
    Q_PROPERTY(QRect coords READ coords WRITE setCoords NOTIFY coordsChanged)
    Q_PROPERTY(QVariant magnifier READ magnifier WRITE setMagnifier NOTIFY magnifierChanged)
    Q_PROPERTY(QVariant activity READ activity WRITE setActivity NOTIFY activityChanged)
    Q_PROPERTY(QString audioPath READ audioPath WRITE setAudioPath NOTIFY audioPathChanged)
    Q_PROPERTY(bool karaoke READ karaoke WRITE setKaraoke NOTIFY karaokeChanged)
    Q_PROPERTY(QRect showAllAnswers READ showAllAnswers WRITE setShowAllAnswers NOTIFY showAllAnswersChanged)
    Q_PROPERTY(QRect lockScreen READ lockScreen WRITE setLockScreen NOTIFY lockScreenChanged)
    Q_PROPERTY(QVariant video READ video WRITE setVideo NOTIFY videoChanged)
    Q_PROPERTY(QVariantList answers READ answers WRITE setAnswers NOTIFY answersChanged)
    Q_PROPERTY(QVariant audioExtra READ audioExtra WRITE setAudioExtra NOTIFY audioExtraChanged)
    Q_PROPERTY(QVariantList freeTextFields READ freeTextFields WRITE setFreeTextFields NOTIFY freeTextFieldsChanged)
    Q_PROPERTY(QRect checkAnswer READ checkAnswer WRITE setCheckAnswer NOTIFY checkAnswerChanged)

public:
    explicit Section(QObject *parent = nullptr) : QObject(parent),
        _magnifier(nullptr), _activity(nullptr), _video(nullptr), _audio_extra(nullptr) { }

    QString _title;
    QString _type;
    QRect _coords;
    Magnifier *_magnifier;
    Activity *_activity;
    QString _audio_path;
    bool _karaoke = false;   // audio section has word-level karaoke timing in audio/audio.json
    QRect _show_all_answers;
    QRect _lock_screen;
    Video *_video;
    AudioExtra *_audio_extra;
    QVector<Answer*> _answers;
    QVector<FreeTextFields*> _freeTextFields;
    QRect _checkAnswer;

    QString title() const { return _title; }
    void setTitle(const QString &title) {
        if (_title != title) {
            _title = title;
            emit titleChanged();
        }
    }

    QString type() const { return _type; }
    void setType(const QString &type) {
        if (_type != type) {
            _type = type;
            emit typeChanged();
        }
    }

    QRect coords() const { return _coords; }
    void setCoords(const QRect &coords) {
        if (_coords != coords) {
            _coords = coords;
            emit coordsChanged();
        }
    }

    QVariant magnifier() const { return QVariant::fromValue(_magnifier); }
    void setMagnifier(const QVariant &magnifier) {
        Magnifier *newMagnifier = qobject_cast<Magnifier*>(magnifier.value<QObject*>());
        if (_magnifier != newMagnifier) {
            _magnifier = newMagnifier;
            emit magnifierChanged();
        }
    }

    QVariant activity() const { return QVariant::fromValue(_activity); }
    void setActivity(const QVariant &activity) {
        Activity *newActivity = qobject_cast<Activity*>(activity.value<QObject*>());
        if (_activity != newActivity) {
            _activity = newActivity;
            emit activityChanged();
        }
    }

    QString audioPath() const { return _audio_path; }
    void setAudioPath(const QString &audioPath) {
        if (_audio_path != audioPath) {
            _audio_path = audioPath;
            emit audioPathChanged();
        }
    }

    bool karaoke() const { return _karaoke; }
    void setKaraoke(bool karaoke) {
        if (_karaoke != karaoke) {
            _karaoke = karaoke;
            emit karaokeChanged();
        }
    }

    QRect showAllAnswers() const { return _show_all_answers; }
    void setShowAllAnswers(const QRect &showAllAnswers) {
        if (_show_all_answers != showAllAnswers) {
            _show_all_answers = showAllAnswers;
            emit showAllAnswersChanged();
        }
    }

    QRect lockScreen() const { return _lock_screen; }
    void setLockScreen(const QRect &lockScreen) {
        if (_lock_screen != lockScreen) {
            _lock_screen = lockScreen;
            emit lockScreenChanged();
        }
    }

    QVariant video() const { return QVariant::fromValue(_video); }
    void setVideo(const QVariant &video) {
        Video *newVideo = qobject_cast<Video*>(video.value<QObject*>());
        if (_video != newVideo) {
            _video = newVideo;
            emit videoChanged();
        }
    }

    QVariantList answers() const {
        QVariantList l;
        for (Answer *a : _answers) {
            l << QVariant::fromValue(a);
        }
        return l;
    }
    void setAnswers(const QVariantList &answers) {
        _answers.clear();
        for (const QVariant &a : answers) {
            Answer *answer = qobject_cast<Answer*>(a.value<QObject*>());
            if (answer) {
                _answers.append(answer);
            }
        }
        emit answersChanged();
    }

    Q_INVOKABLE Answer* createNewAnswer(int x, int y, int w, int h, const QString &text = "" ) {
        try {
            Answer *answer = new Answer(this); // Parent set edildi
            answer->setCoords(QRect(x,y,w,h));
            answer->setText(text);
                   
            _answers.push_back(answer);
            emit answersChanged();
            return answer;
        } catch (...) {
            qCritical("Exception in Section::createNewAnswer");
            return nullptr;
        }
    }

    Q_INVOKABLE Answer * createNewAnswerDrawMacthedLine(int x, int y, int w, int h ) {
        Answer *answer = new Answer(this); // Parent set edildi
        answer->setRectBegin(QRect(x,y,w,h));
        answer->setRectEnd(QRect(x+ 150,y,w,h));
        answer->setLineBegin(QPoint(x, y));
        answer->setLineEnd(QPoint(x+150, y));
        answer->setOpacity(0.5);
        
        
        _answers.push_back(answer);
        emit answersChanged();
        return answer;
    }

    Q_INVOKABLE void removeAnswer(int index) {
        if (index >= 0 && index < _answers.size()) {
            Answer *answer = _answers[index];
            _answers.removeAt(index);
            if (answer) {
                answer->deleteLater(); // Qt-safe deletion
            }
            emit answersChanged();
        }
    }

    QVariant audioExtra() const { return QVariant::fromValue(_audio_extra); }
    void setAudioExtra(const QVariant &audioExtra) {
        AudioExtra *newAudioExtra = qobject_cast<AudioExtra*>(audioExtra.value<QObject*>());
        if (_audio_extra != newAudioExtra) {
            _audio_extra = newAudioExtra;
            emit audioExtraChanged();
        }
    }

    Q_INVOKABLE AudioExtra* createAudioExtra(const QString &text = "" ) {
        AudioExtra *newAudioExtra = new AudioExtra(this); // Parent set edildi
        newAudioExtra->setPath(text);
        _audio_extra = newAudioExtra;
        emit audioExtraChanged();
        return newAudioExtra;
    }

    QVariantList freeTextFields() const {
        QVariantList l;
        for (FreeTextFields *r : _freeTextFields) {
            l << QVariant::fromValue(r);
        }
        return l;
    }
    void setFreeTextFields(const QVariantList &freeTextFields) {
        _freeTextFields.clear();
        for (const QVariant &r : freeTextFields) {
            FreeTextFields *freeTextField = qobject_cast<FreeTextFields*>(r.value<QObject*>());
            if (freeTextField) {
                _freeTextFields.append(freeTextField);
            }
        }
        emit freeTextFieldsChanged();
    }

    QRect checkAnswer() const { return _checkAnswer; }
    void setCheckAnswer(const QRect &checkAnswer) {
        if (_checkAnswer != checkAnswer) {
            _checkAnswer = checkAnswer;
            emit checkAnswerChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject sectionObj;
        
        if (!_title.isEmpty()) {
            sectionObj["title"] = _title;
        }
        
        if (!_type.isEmpty()) {
            sectionObj["type"] = _type;
        }
        
        if (!_audio_path.isEmpty()) {
            sectionObj["audio_path"] = _audio_path;
        }

        // Word-level karaoke timing lives in audio/audio.json (keyed by file
        // name); the section only flags that the reader should load it.
        if (_karaoke) {
            sectionObj["karaoke"] = true;
        }

        if (_video && !_video->_path.isEmpty()) {
            sectionObj["video_path"] = _video->_path;
        }

        if (!_coords.isNull() && _coords.isValid()) {
            QJsonObject coordsObj;
            coordsObj["x"] = _coords.x();
            coordsObj["y"] = _coords.y();
            coordsObj["w"] = _coords.width();
            coordsObj["h"] = _coords.height();
            sectionObj["coords"] = coordsObj;
        }

        if (_magnifier && (!_magnifier->_sectionPath.isEmpty() || (_magnifier->_coords.isValid() && !_magnifier->_coords.isNull()))) {
            QJsonObject magnifierObj;
            
            if (!_magnifier->_sectionPath.isEmpty()) {
                magnifierObj["section_path"] = _magnifier->_sectionPath;
            }
            
            if (_magnifier->_coords.isValid() && !_magnifier->_coords.isNull()) {
                QJsonObject magnifierCoords;
                magnifierCoords["x"] = _magnifier->_coords.x();
                magnifierCoords["y"] = _magnifier->_coords.y();
                magnifierCoords["w"] = _magnifier->_coords.width();
                magnifierCoords["h"] = _magnifier->_coords.height();
                magnifierObj["coords"] = magnifierCoords;
            }
            
            sectionObj["magnifier"] = magnifierObj;
        }

        if (!_freeTextFields.isEmpty()) {
            QJsonArray freeTextFieldsArray;
            for (const FreeTextFields *field : _freeTextFields) {
                if (field) { // Null check eklendi
                    freeTextFieldsArray.append(field->toJson());
                }
            }
            sectionObj["freeTextFields"] = freeTextFieldsArray;
        }

        if (_activity) {
            sectionObj["activity"] = _activity->toJson();
        }

        if (!_answers.isEmpty()) {
            QJsonArray answersArray;
            for (const Answer *answer : _answers) {
                if (answer) { // Null check eklendi
                    answersArray.append(answer->toJson());
                }
            }
            sectionObj["answer"] = answersArray;
        }

        if (_audio_extra) {
            sectionObj["audio_extra"] = _audio_extra->toJson();
        }

        if (!_show_all_answers.isNull() && _show_all_answers.isValid()) {
            QJsonObject showAllAnswersObj;
            showAllAnswersObj["x"] = _show_all_answers.x();
            showAllAnswersObj["y"] = _show_all_answers.y();
            showAllAnswersObj["w"] = _show_all_answers.width();
            showAllAnswersObj["h"] = _show_all_answers.height();
            sectionObj["show_all_answers"] = showAllAnswersObj;
        }

        if (!_lock_screen.isNull() && _lock_screen.isValid()) {
            QJsonObject lockScreenObj;
            lockScreenObj["x"] = _lock_screen.x();
            lockScreenObj["y"] = _lock_screen.y();
            lockScreenObj["w"] = _lock_screen.width();
            lockScreenObj["h"] = _lock_screen.height();
            sectionObj["lock_screen"] = lockScreenObj;
        }

        if (!_checkAnswer.isNull() && _checkAnswer.isValid()) {
            QJsonObject checkAnswerObj;
            checkAnswerObj["x"] = _checkAnswer.x();
            checkAnswerObj["y"] = _checkAnswer.y();
            checkAnswerObj["w"] = _checkAnswer.width();
            checkAnswerObj["h"] = _checkAnswer.height();
            sectionObj["checkAnswer"] = checkAnswerObj;
        }

        return sectionObj;
    }

signals:
    void titleChanged();
    void typeChanged();
    void coordsChanged();
    void magnifierChanged();
    void activityChanged();
    void audioPathChanged();
    void karaokeChanged();
    void showAllAnswersChanged();
    void lockScreenChanged();
    void videoChanged();
    void answersChanged();
    void audioExtraChanged();
    void freeTextFieldsChanged();
    void checkAnswerChanged();

public slots:
    Q_INVOKABLE void notifyAnswersChanged() {
        emit answersChanged();
    }

};

struct Page : public QObject {
    Q_OBJECT
    Q_PROPERTY(int page_number READ pageNumber WRITE setPageNumber NOTIFY pageNumberChanged)
    Q_PROPERTY(QString image_path READ imagePath WRITE setImagePath NOTIFY imagePathChanged)
    Q_PROPERTY(QVariantList sections READ sections WRITE setSections NOTIFY sectionsChanged)
    // Set once a human reorders this page's activities in the editor, so a
    // re-Analyze knows the section order is human-owned and must not be
    // auto-reordered over.
    Q_PROPERTY(bool manual_order READ manualOrder WRITE setManualOrder NOTIFY manualOrderChanged)

public:
    explicit Page(QObject *parent = nullptr) : QObject(parent), _page_number(0) {}
    int _page_number;
    QString _image_path;
    QVector<Section*> _sections;
    bool _manual_order = false;

    int pageNumber() const { return _page_number; }
    void setPageNumber(int pageNumber) {
        if (_page_number != pageNumber) {
            _page_number = pageNumber;
            emit pageNumberChanged();
        }
    }

    QString imagePath() const { return _image_path; }
    void setImagePath(const QString &imagePath) {
        if (_image_path != imagePath) {
            _image_path = imagePath;
            emit imagePathChanged();
        }
    }

    QVariantList sections() const {
        QVariantList l;
        for (Section *s : _sections) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setSections(const QVariantList &sections) {
        _sections.clear();
        for (const QVariant &s : sections) {
            Section *section = qobject_cast<Section*>(s.value<QObject*>());
            if (section) {
                _sections.append(section);
            }
        }
        emit sectionsChanged();
    }

    bool manualOrder() const { return _manual_order; }
    void setManualOrder(bool manualOrder) {
        if (_manual_order != manualOrder) {
            _manual_order = manualOrder;
            emit manualOrderChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject pageObj;

        if (_page_number != 0) {
            pageObj["page_number"] = _page_number;
        }

        if (_manual_order) {
            pageObj["manual_order"] = true;
        }
        
        if (!_image_path.isEmpty()) {
            pageObj["image_path"] = _image_path;
        }

        if (!_sections.isEmpty()) {
            QJsonArray sectionsArray;
            for (const Section *section : _sections) {
                if (section) { // Null check eklendi
                    sectionsArray.append(section->toJson());
                }
            }
            pageObj["sections"] = sectionsArray;
        }

        return pageObj;
    }

    Q_INVOKABLE Section * createNewAudioSection(int x, int y, int w , int h, const QString &audioPath) {
        Section *newSection = new Section(this); // Parent set edildi
        newSection->setType("audio");
        newSection->setAudioPath(audioPath);
        newSection->setCoords(QRect(x,y,w,h));
        _sections.append(newSection);

        emit sectionsChanged();
        return newSection;
    }

    Q_INVOKABLE Section * createNewVideoSection(int x, int y, int w , int h, const QString &videoPath) {
        Section *newSection = new Section(this); // Parent set edildi
        newSection->setType("video");
        Video *video = new Video(newSection); // Parent set edildi
        video->setPath(videoPath);
        newSection->setVideo(QVariant::fromValue(video));
        newSection->setCoords(QRect(x,y,w,h));
        _sections.append(newSection);

        emit sectionsChanged();
        return newSection;
    }

    Q_INVOKABLE Section * createNewActivity(int x, int y, int w , int h, const QString &type, int circleCount = 2, int markCount = 2) {
        Section *newSection = new Section(this); // Parent set edildi
        Activity *activity = new Activity(newSection); // Parent set edildi
        activity->setCoords(QRect(x,y,w,h));
        activity->setType(type);
        activity->setCircleCount(circleCount);
        activity->setMarkCount(markCount);
        newSection->setActivity(QVariant::fromValue(activity));
        _sections.append(newSection);

        emit sectionsChanged();
        return newSection;
    }

    Q_INVOKABLE Section * refreshSection() {
        // CRASH-SAFE: Sadece signal emit et, gereksiz allocation yapma
        emit sectionsChanged();
        return nullptr;
    }
    Q_INVOKABLE Section * getAvailableSection(const QString &type) {
        for (Section *section: _sections) {
            if (section && section->type() == type) { // Null check eklendi
                return section;
            }
        }

        Section *newSection = new Section(this); // Parent set edildi
        newSection->setType(type);
        _sections.push_back(newSection);
        emit sectionsChanged();
        return newSection;
    }

    Q_INVOKABLE void removeSection(int index) {
        if (index >= 0 && index < _sections.size()) {
            Section *section = _sections[index];
            _sections.removeAt(index);
            if (section) {
                section->deleteLater(); // Qt-safe deletion
            }
            emit sectionsChanged();
        }
    }

    // Move the activity at `from` to sit at 1-based reading position `to`
    // (both taken as array indices). Reordering the sections vector is the
    // whole feature: the array order IS the reader's activity sequence and
    // the badge number. Flags the page manual_order so re-Analyze won't
    // clobber the human's choice.
    Q_INVOKABLE void moveSection(int from, int to) {
        if (from < 0 || from >= _sections.size()) return;
        if (to < 0 || to >= _sections.size()) return;
        if (from == to) return;
        Section *s = _sections.takeAt(from);
        _sections.insert(to, s);
        setManualOrder(true);
        emit sectionsChanged();
    }

    // Move a fill blank (answer) to a new position WITHIN its section, so a
    // reviewer can fix the order the reader opens the blanks in. Same idea as
    // moveSection but one level down, on the section's answer array.
    Q_INVOKABLE void moveAnswer(int sectionIndex, int from, int to) {
        if (sectionIndex < 0 || sectionIndex >= _sections.size()) return;
        Section *s = _sections[sectionIndex];
        if (!s) return;
        if (from < 0 || from >= s->_answers.size()) return;
        if (to < 0 || to >= s->_answers.size()) return;
        if (from == to) return;
        Answer *a = s->_answers.takeAt(from);
        s->_answers.insert(to, a);
        setManualOrder(true);
        emit s->answersChanged();
    }


signals:
    void pageNumberChanged();
    void imagePathChanged();
    void sectionsChanged();
    void manualOrderChanged();
};

struct QuizGameQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString question READ question WRITE setQuestion NOTIFY questionChanged)
    Q_PROPERTY(QString optionA READ optionA WRITE setOptionA NOTIFY optionAChanged)
    Q_PROPERTY(QString optionB READ optionB WRITE setOptionB NOTIFY optionBChanged)
    Q_PROPERTY(QString optionC READ optionC WRITE setOptionC NOTIFY optionCChanged)
    Q_PROPERTY(QString optionD READ optionD WRITE setOptionD NOTIFY optionDChanged)
    Q_PROPERTY(QString optionE READ optionE WRITE setOptionE NOTIFY optionEChanged)
    Q_PROPERTY(QString correctAnswer READ correctAnswer WRITE setCorrectAnswer NOTIFY correctAnswerChanged)

public:
    explicit QuizGameQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QString _question;
    QString _optionA;
    QString _optionB;
    QString _optionC;
    QString _optionD;
    QString _optionE;
    QString _correctAnswer;

    QString question() const { return _question; }
    void setQuestion(const QString &question) {
        if (_question != question) {
            _question = question;
            emit questionChanged();
        }
    }

    QString optionA() const { return _optionA; }
    void setOptionA(const QString &optionA) {
        if (_optionA != optionA) {
            _optionA = optionA;
            emit optionAChanged();
        }
    }

    QString optionB() const { return _optionB; }
    void setOptionB(const QString &optionB) {
        if (_optionB != optionB) {
            _optionB = optionB;
            emit optionBChanged();
        }
    }

    QString optionC() const { return _optionC; }
    void setOptionC(const QString &optionC) {
        if (_optionC != optionC) {
            _optionC = optionC;
            emit optionCChanged();
        }
    }

    QString optionD() const { return _optionD; }
    void setOptionD(const QString &optionD) {
        if (_optionD != optionD) {
            _optionD = optionD;
            emit optionDChanged();
        }
    }

    QString optionE() const { return _optionE; }
    void setOptionE(const QString &optionE) {
        if (_optionE != optionE) {
            _optionE = optionE;
            emit optionEChanged();
        }
    }

    QString correctAnswer() const { return _correctAnswer; }
    void setCorrectAnswer(const QString &correctAnswer) {
        if (_correctAnswer != correctAnswer) {
            _correctAnswer = correctAnswer;
            emit correctAnswerChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject questionObj;
        
        if (!_question.isEmpty()) {
            questionObj["question"] = _question;
        }
        
        if (!_optionA.isEmpty()) {
            questionObj["optionA"] = _optionA;
        }
        
        if (!_optionB.isEmpty()) {
            questionObj["optionB"] = _optionB;
        }
        
        if (!_optionC.isEmpty()) {
            questionObj["optionC"] = _optionC;
        }
        
        if (!_optionD.isEmpty()) {
            questionObj["optionD"] = _optionD;
        }
        
        if (!_optionE.isEmpty()) {
            questionObj["optionE"] = _optionE;
        }
        
        if (!_correctAnswer.isEmpty()) {
            questionObj["correctAnswer"] = _correctAnswer;
        }
        
        return questionObj;
    }

signals:
    void questionChanged();
    void optionAChanged();
    void optionBChanged();
    void optionCChanged();
    void optionDChanged();
    void optionEChanged();
    void correctAnswerChanged();
};

struct SentenceGameQuestion : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList words READ words WRITE setWords NOTIFY wordsChanged)

public:
    explicit SentenceGameQuestion(QObject *parent = nullptr) : QObject(parent) {}

    QVector<QString> _words;

    QVariantList words() const {
        QVariantList l;
        for (const QString &s : _words) {
            l << QVariant::fromValue(s);
        }
        return l;
    }

    void setWords(const QVariantList &words) {
        _words.clear();
        for (const QVariant &w : words) {
            if (w.canConvert<QString>()) {
                _words.append(w.toString());
            }
        }
        emit wordsChanged();
    }

    QJsonObject toJson() const {
        QJsonObject questionObj;
        
        if (!_words.isEmpty()) {
            QJsonArray wordsArray;
            for (const QString &word : _words) {
                wordsArray.append(word);
            }
            questionObj["words"] = wordsArray;
        }
        
        return questionObj;
    }

signals:
    void wordsChanged();
};

struct MemoryGameImages : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString image READ image WRITE setImage NOTIFY imageChanged)

public:
    explicit MemoryGameImages(QObject *parent = nullptr) : QObject(parent) {}

    QString _image;

    QString image() const { return _image; }
    void setImage(const QString &image) {
        if (_image != image) {
            _image = image;
            emit imageChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject imageObj;
        
        if (!_image.isEmpty()) {
            imageObj["image_path"] = _image;
        }
        
        return imageObj;
    }

signals:
    void imageChanged();
};

struct Game : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QString type READ type WRITE setType NOTIFY typeChanged)
    Q_PROPERTY(QString imagePath READ imagePath WRITE setImagePath NOTIFY imagePathChanged)
    Q_PROPERTY(QVariantList secretwords READ secretwords WRITE setSecretwords NOTIFY secretwordsChanged)
    Q_PROPERTY(QVariantList rules READ rules WRITE setRules NOTIFY rulesChanged)
    Q_PROPERTY(QString imageCover READ imageCover WRITE setImageCover NOTIFY imageCoverChanged)
    Q_PROPERTY(QVariantList quizGameQuestions READ quizGameQuestions WRITE setQuizGameQuestions NOTIFY quizGameQuestionsChanged)
    Q_PROPERTY(QVariantList sentenceGameQuestions READ sentenceGameQuestions WRITE setSentenceGameQuestions NOTIFY sentenceGameQuestionsChanged)
    Q_PROPERTY(QVariantList memoryGameImages READ memoryGameImages WRITE setMemoryGameImages NOTIFY memoryGameImagesChanged)

public:
    explicit Game(QObject *parent = nullptr) : QObject(parent) {}

    QString _name;
    QString _type;
    QString _imagePath;
    QVector<QString> _secretwords;
    QVector<QString> _rules;
    QString _imageCover;
    QVector<QuizGameQuestion*> _quizGameQuestions;
    QVector<SentenceGameQuestion*> _sentenceGameQuestions;
    QVector<MemoryGameImages*> _memoryGameImages;

    QString name() const { return _name; }
    void setName(const QString &name) {
        if (_name != name) {
            _name = name;
            emit nameChanged();
        }
    }

    QString type() const { return _type; }
    void setType(const QString &type) {
        if (_type != type) {
            _type = type;
            emit typeChanged();
        }
    }

    QString imagePath() const { return _imagePath; }
    void setImagePath(const QString &imagePath) {
        if (_imagePath != imagePath) {
            _imagePath = imagePath;
            emit imagePathChanged();
        }
    }

    QString imageCover() const { return _imageCover; }
    void setImageCover(const QString &imageCover) {
        if (_imageCover != imageCover) {
            _imageCover = imageCover;
            emit imageCoverChanged();
        }
    }

    QVariantList secretwords() const {
        QVariantList l;
        for (const QString &s : _secretwords) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setSecretwords(const QVariantList &secretwords) {
        _secretwords.clear();
        for (const QVariant &w : secretwords) {
            if (w.canConvert<QString>()) {
                _secretwords.append(w.toString());
            }
        }
        emit secretwordsChanged();
    }

    QVariantList rules() const {
        QVariantList l;
        for (const QString &s : _rules) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setRules(const QVariantList &rules) {
        _rules.clear();
        for (const QVariant &r : rules) {
            if (r.canConvert<QString>()) {
                _rules.append(r.toString());
            }
        }
        emit rulesChanged();
    }

    QVariantList quizGameQuestions() const {
        QVariantList l;
        for (QuizGameQuestion *s : _quizGameQuestions) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setQuizGameQuestions(const QVariantList &quizGameQuestions) {
        _quizGameQuestions.clear();
        for (const QVariant &q : quizGameQuestions) {
            QuizGameQuestion *quiz = qobject_cast<QuizGameQuestion*>(q.value<QObject*>());
            if (quiz) {
                _quizGameQuestions.append(quiz);
            }
        }
        emit quizGameQuestionsChanged();
    }

    QVariantList sentenceGameQuestions() const {
        QVariantList l;
        for (SentenceGameQuestion *s : _sentenceGameQuestions) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setSentenceGameQuestions(const QVariantList &sentenceGameQuestions) {
        _sentenceGameQuestions.clear();
        for (const QVariant &sq : sentenceGameQuestions) {
            SentenceGameQuestion *sentence = qobject_cast<SentenceGameQuestion*>(sq.value<QObject*>());
            if (sentence) {
                _sentenceGameQuestions.append(sentence);
            }
        }
        emit sentenceGameQuestionsChanged();
    }

    QVariantList memoryGameImages() const {
        QVariantList l;
        for (MemoryGameImages *s : _memoryGameImages) {
            l << QVariant::fromValue(s);
        }
        return l;
    }
    void setMemoryGameImages(const QVariantList &memoryGameImages) {
        _memoryGameImages.clear();
        for (const QVariant &m : memoryGameImages) {
            MemoryGameImages *image = qobject_cast<MemoryGameImages*>(m.value<QObject*>());
            if (image) {
                _memoryGameImages.append(image);
            }
        }
        emit memoryGameImagesChanged();
    }

    QJsonObject toJson() const {
        QJsonObject gameObj;
        
        if (!_name.isEmpty()) {
            gameObj["name"] = _name;
        }
        
        if (!_type.isEmpty()) {
            gameObj["type"] = _type;
        }
        
        if (!_imagePath.isEmpty()) {
            gameObj["image_path"] = _imagePath;
        }
        
        if (!_imageCover.isEmpty()) {
            gameObj["cover_image_path"] = _imageCover;
        }

        if (!_secretwords.isEmpty()) {
            QJsonArray secretWordsArray;
            for (const QString &word : _secretwords) {
                secretWordsArray.append(word);
            }
            gameObj["secretwords"] = secretWordsArray;
        }

        if (!_rules.isEmpty()) {
            QJsonArray rulesArray;
            for (const QString &rule : _rules) {
                rulesArray.append(rule);
            }
            gameObj["rules"] = rulesArray;
        }

        if (!_quizGameQuestions.isEmpty()) {
            QJsonArray quizQuestionsArray;
            for (const QuizGameQuestion *question : _quizGameQuestions) {
                if (question) { // Null check eklendi
                    quizQuestionsArray.append(question->toJson());
                }
            }
            gameObj["quiz_questions"] = quizQuestionsArray;
        }

        if (!_sentenceGameQuestions.isEmpty()) {
            QJsonArray sentenceQuestionsArray;
            for (const SentenceGameQuestion *question : _sentenceGameQuestions) {
                if (question) { // Null check eklendi
                    sentenceQuestionsArray.append(question->toJson());
                }
            }
            gameObj["sentence_questions"] = sentenceQuestionsArray;
        }

        if (!_memoryGameImages.isEmpty()) {
            QJsonArray memoryImagesArray;
            for (const MemoryGameImages *image : _memoryGameImages) {
                if (image) { // Null check eklendi
                    memoryImagesArray.append(image->toJson());
                }
            }
            gameObj["memory_images"] = memoryImagesArray;
        }

        return gameObj;
    }

signals:
    void nameChanged();
    void typeChanged();
    void imagePathChanged();
    void secretwordsChanged();
    void rulesChanged();
    void imageCoverChanged();
    void quizGameQuestionsChanged();
    void sentenceGameQuestionsChanged();
    void memoryGameImagesChanged();
};

struct Module : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QString type READ type WRITE setType NOTIFY typeChanged)
    Q_PROPERTY(QVariantList pages READ pages WRITE setPages NOTIFY pagesChanged)
    Q_PROPERTY(QVariantList games READ games WRITE setGames NOTIFY gamesChanged)

public:
    explicit Module(QObject *parent = nullptr) : QObject(parent) {}

    QString _name;
    QString _type;
    QVector<Page*> _pages;
    QVector<Game*> _games;

    QString name() const { return _name; }
    void setName(const QString &name) {
        if (_name != name) {
            _name = name;
            emit nameChanged();
        }
    }

    QString type() const { return _type; }
    void setType(const QString &type) {
        if (_type != type) {
            _type = type;
            emit typeChanged();
        }
    }

    QVariantList pages() const {
        QVariantList l;
        for (Page *c : _pages) {
            l << QVariant::fromValue(c);
        }
        return l;
    }
    void setPages(const QVariantList &pages) {
        _pages.clear();
        for (const QVariant &p : pages) {
            Page *page = qobject_cast<Page*>(p.value<QObject*>());
            if (page) {
                _pages.append(page);
            }
        }
        emit pagesChanged();
    }

    QVariantList games() const {
        QVariantList l;
        for (Game *c : _games) {
            l << QVariant::fromValue(c);
        }
        return l;
    }
    void setGames(const QVariantList &games) {
        _games.clear();
        for (const QVariant &g : games) {
            Game *game = qobject_cast<Game*>(g.value<QObject*>());
            if (game) {
                _games.append(game);
            }
        }
        emit gamesChanged();
    }

    QJsonObject toJson() const {
        QJsonObject moduleObj;
        
        if (!_type.isEmpty()) {
            moduleObj["type"] = _type;
        }
        
        if (!_name.isEmpty()) {
            moduleObj["name"] = _name;
        }

        if (!_games.isEmpty()) {
            QJsonArray gamesArray;
            for (const Game *game : _games) {
                if (game) { // Null check eklendi
                    gamesArray.append(game->toJson());
                }
            }
            moduleObj["games"] = gamesArray;
        }

        if (!_pages.isEmpty()) {
            QJsonArray pagesArray;
            for (const Page *page : _pages) {
                if (page) { // Null check eklendi
                    pagesArray.append(page->toJson());
                }
            }
            moduleObj["pages"] = pagesArray;
        }

        return moduleObj;
    }

signals:
    void nameChanged();
    void typeChanged();
    void pagesChanged();
    void gamesChanged();
};

struct Book : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString type READ type WRITE setType NOTIFY typeChanged)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(bool isModuleSideLeft READ isModuleSideLeft WRITE setIsModuleSideLeft NOTIFY isModuleSideLeftChanged)
    // Per-book reader option: when true, the reader shows clickable hints on
    // fill activities. Authored here, consumed by the reader. Default false.
    Q_PROPERTY(bool showClickableHints READ showClickableHints WRITE setShowClickableHints NOTIFY showClickableHintsChanged)
    Q_PROPERTY(QVariantList modules READ modules WRITE setModules NOTIFY modulesChanged)
    Q_PROPERTY(QVariantList pages READ pages NOTIFY pagesChanged)
    Q_PROPERTY(QVariantList games READ games NOTIFY gamesChanged)

public:
    explicit Book(QObject *parent = nullptr) : QObject(parent) {}

    QString _type;
    QString _name;
    bool _isModuleSideLeft;
    bool _show_clickable_hints = false;   // reader hint toggle; off by default
    QVector<Module*> _modules;
    // NOTE: pages and games are computed flat views over _modules; not stored.
    // Modules own their pages/games (Qt parent chain). Avoids dangling
    // pointers and stale flat lists that caused crashes during save.

    QString type() const { return _type; }
    void setType(const QString &type) {
        if (_type != type) {
            _type = type;
            emit typeChanged();
        }
    }

    QString name() const { return _name; }
    void setName(const QString &name) {
        if (_name != name) {
            _name = name;
            emit nameChanged();
        }
    }

    bool isModuleSideLeft() const { return _isModuleSideLeft; }
    void setIsModuleSideLeft(bool isModuleSideLeft) {
        if (_isModuleSideLeft != isModuleSideLeft) {
            _isModuleSideLeft = isModuleSideLeft;
            emit isModuleSideLeftChanged();
        }
    }

    bool showClickableHints() const { return _show_clickable_hints; }
    void setShowClickableHints(bool show) {
        if (_show_clickable_hints != show) {
            _show_clickable_hints = show;
            emit showClickableHintsChanged();
        }
    }

    QVariantList modules() const {
        QVariantList l;
        for (Module *m : _modules) {
            l << QVariant::fromValue(m);
        }
        return l;
    }
    void setModules(const QVariantList &modules) {
        _modules.clear();
        for (const QVariant &m : modules) {
            Module *module = qobject_cast<Module*>(m.value<QObject*>());
            if (module) {
                _modules.append(module);
            }
        }
        emit modulesChanged();
    }

    // Flat computed view across all modules. Safe to call any time — no
    // stored pointer state that could go stale.
    QVariantList pages() const {
        QVariantList l;
        for (Module *m : _modules) {
            if (!m) continue;
            for (Page *p : m->_pages) {
                if (p) l << QVariant::fromValue(p);
            }
        }
        return l;
    }

    QVariantList games() const {
        QVariantList l;
        for (Module *m : _modules) {
            if (!m) continue;
            for (Game *g : m->_games) {
                if (g) l << QVariant::fromValue(g);
            }
        }
        return l;
    }

    QJsonObject toJson() const {
        QJsonObject bookObj;

        if (!_type.isEmpty()) {
            bookObj["type"] = _type;
        }

        if (!_name.isEmpty()) {
            bookObj["name"] = _name;
        }

        bookObj["is_module_side_left"] = _isModuleSideLeft;
        bookObj["show_clickable_hints"] = _show_clickable_hints;

        if (!_modules.isEmpty()) {
            QJsonArray modulesArray;
            for (const Module *module : _modules) {
                if (module) { // Null check eklendi
                    modulesArray.append(module->toJson());
                }
            }
            bookObj["modules"] = modulesArray;
        }

        return bookObj;
    }

    Q_INVOKABLE Module* addModule(const QString &name) {
        Module *m = new Module(this);
        m->_name = name;
        m->_type = "";
        _modules.append(m);
        emit modulesChanged();
        emit pagesChanged();
        emit gamesChanged();
        return m;
    }

    Q_INVOKABLE void removeModule(int index) {
        if (index < 0 || index >= _modules.size()) return;
        Module *m = _modules.takeAt(index);
        // Cascade: pages and games owned by this module are deleted with it.
        if (m) m->deleteLater();
        emit modulesChanged();
        emit pagesChanged();
        emit gamesChanged();
    }

    Q_INVOKABLE void moveModule(int from, int to) {
        if (from < 0 || from >= _modules.size()) return;
        if (to < 0 || to >= _modules.size()) return;
        if (from == to) return;
        _modules.move(from, to);
        emit modulesChanged();
        emit pagesChanged();
        emit gamesChanged();
    }

    Q_INVOKABLE void movePageToModule(int pageNumber, int targetModuleIndex) {
        if (targetModuleIndex < 0 || targetModuleIndex >= _modules.size()) return;
        Module *target = _modules[targetModuleIndex];
        if (!target) return;

        Page *moved = nullptr;
        for (Module *m : _modules) {
            if (!m) continue;
            for (int i = 0; i < m->_pages.size(); ++i) {
                Page *p = m->_pages[i];
                if (p && p->_page_number == pageNumber) {
                    if (m == target) return; // already there
                    moved = p;
                    m->_pages.removeAt(i);
                    emit m->pagesChanged();
                    break;
                }
            }
            if (moved) break;
        }
        if (!moved) return;

        // Reparent so the page's Qt parent matches its new owning module.
        // Without this, removing the old module would delete the page even
        // though the new module still references it.
        moved->setParent(target);

        // Insert keeping pages sorted by page_number
        int insertIdx = target->_pages.size();
        for (int i = 0; i < target->_pages.size(); ++i) {
            Page *p = target->_pages[i];
            if (p && p->_page_number > pageNumber) {
                insertIdx = i;
                break;
            }
        }
        target->_pages.insert(insertIdx, moved);
        emit target->pagesChanged();
        emit modulesChanged();
        emit pagesChanged();
    }

    // insertIndex < 0 → append to end of target module (preserves manual order).
    // insertIndex >= 0 → insert contiguously starting at that visual position in target.
    Q_INVOKABLE void movePagesToModule(const QVariantList &pageNumbers, int targetModuleIndex,
                                        int insertIndex = -1) {
        if (targetModuleIndex < 0 || targetModuleIndex >= _modules.size()) return;
        Module *target = _modules[targetModuleIndex];
        if (!target) return;

        QSet<int> wanted;
        for (const QVariant &v : pageNumbers) {
            bool ok = false;
            int pn = v.toInt(&ok);
            if (ok) wanted.insert(pn);
        }
        if (wanted.isEmpty()) return;

        QVector<Page*> pagesToInsert;
        QSet<int> already;
        for (Page *p : target->_pages) {
            if (p) already.insert(p->_page_number);
        }

        for (Module *m : _modules) {
            if (!m || m == target) continue;
            bool changed = false;
            for (int i = m->_pages.size() - 1; i >= 0; --i) {
                Page *p = m->_pages[i];
                if (p && wanted.contains(p->_page_number)
                        && !already.contains(p->_page_number)) {
                    pagesToInsert.append(p);
                    already.insert(p->_page_number);
                    m->_pages.removeAt(i);
                    changed = true;
                }
            }
            if (changed) emit m->pagesChanged();
        }

        if (pagesToInsert.isEmpty()) return;

        // Keep dragged pages in ascending page_number order for predictability.
        std::sort(pagesToInsert.begin(), pagesToInsert.end(),
                  [](Page *a, Page *b) { return a->_page_number < b->_page_number; });

        // Reparent each moved page to its new owning module before inserting.
        for (Page *p : pagesToInsert) {
            if (p) p->setParent(target);
        }

        if (insertIndex < 0 || insertIndex > target->_pages.size()) {
            for (Page *p : pagesToInsert) target->_pages.append(p);
        } else {
            int pos = insertIndex;
            for (Page *p : pagesToInsert) {
                target->_pages.insert(pos, p);
                pos++;
            }
        }
        emit target->pagesChanged();
        emit modulesChanged();
        emit pagesChanged();
    }

    Q_INVOKABLE void reorderPagesInModule(int moduleIndex, const QVariantList &newOrder) {
        if (moduleIndex < 0 || moduleIndex >= _modules.size()) return;
        Module *m = _modules[moduleIndex];
        if (!m) return;
        if (newOrder.size() != m->_pages.size()) return;
        QSet<Page*> existing(m->_pages.begin(), m->_pages.end());
        QVector<Page*> reordered;
        reordered.reserve(newOrder.size());
        for (const QVariant &v : newOrder) {
            Page *p = qobject_cast<Page*>(v.value<QObject*>());
            if (!p || !existing.contains(p)) return;
            reordered.append(p);
        }
        m->_pages = reordered;
        emit m->pagesChanged();
        emit pagesChanged();
    }

    Q_INVOKABLE void reorderModules(const QVariantList &newOrder) {
        if (newOrder.size() != _modules.size()) return;
        QVector<Module*> reordered;
        reordered.reserve(_modules.size());
        for (const QVariant &v : newOrder) {
            Module *m = qobject_cast<Module*>(v.value<QObject*>());
            if (!m || !_modules.contains(m)) return;
            reordered.append(m);
        }
        // Verify no duplicates
        if (reordered.size() != _modules.size()) return;
        _modules = reordered;
        emit modulesChanged();
    }

    // Returns empty string on success, or a user-facing message (already exists / error).
    Q_INVOKABLE QString addPageToFirstModule(int pageNumber) {
        if (pageNumber <= 0) return QStringLiteral("Invalid page number.");
        if (_modules.isEmpty()) return QStringLiteral("No modules available.");

        for (Module *m : _modules) {
            if (!m) continue;
            for (Page *p : m->_pages) {
                if (p && p->_page_number == pageNumber) {
                    return QStringLiteral("Page %1 already exists in \"%2\".")
                            .arg(pageNumber).arg(m->_name);
                }
            }
        }

        Module *firstMod = _modules[0];
        Page *target = new Page(firstMod);
        target->_page_number = pageNumber;

        int insertIdx = firstMod->_pages.size();
        for (int i = 0; i < firstMod->_pages.size(); ++i) {
            Page *p = firstMod->_pages[i];
            if (p && p->_page_number > pageNumber) { insertIdx = i; break; }
        }
        firstMod->_pages.insert(insertIdx, target);
        emit firstMod->pagesChanged();
        emit modulesChanged();
        emit pagesChanged();
        return QString();
    }

    // Kept for API stability. Pages always belong to a module now, so there
    // are no orphans — returns an empty list.
    Q_INVOKABLE QVariantList unassignedPages() const {
        return QVariantList();
    }

    Q_INVOKABLE void renameModule(int index, const QString &name) {
        if (index < 0 || index >= _modules.size()) return;
        Module *m = _modules[index];
        if (!m) return;
        if (m->_name != name) {
            m->_name = name;
            emit m->nameChanged();
        }
    }

signals:
    void typeChanged();
    void nameChanged();
    void isModuleSideLeftChanged();
    void showClickableHintsChanged();
    void modulesChanged();
    void pagesChanged();
    void gamesChanged();
};

struct Vocabulary : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString vocab READ vocab WRITE setVocab NOTIFY vocabChanged)

public:
    explicit Vocabulary(QObject *parent = nullptr) : QObject(parent) {}

    QString _vocab;

    QString vocab() const { return _vocab; }
    void setVocab(const QString &vocab) {
        if (_vocab != vocab) {
            _vocab = vocab;
            emit vocabChanged();
        }
    }

signals:
    void vocabChanged();
};

struct BookSet : public QObject {
    Q_OBJECT
    Q_PROPERTY(int bookCount READ bookCount WRITE setBookCount NOTIFY bookCountChanged)
    Q_PROPERTY(QString publisherName READ publisherName WRITE setPublisherName NOTIFY publisherNameChanged)
    Q_PROPERTY(QString publisherLogoPath READ publisherLogoPath WRITE setPublisherLogoPath NOTIFY publisherLogoPathChanged)
    Q_PROPERTY(QString publisherFullLogoPath READ publisherFullLogoPath WRITE setPublisherFullLogoPath NOTIFY publisherFullLogoPathChanged)
    Q_PROPERTY(QString bookTitle READ bookTitle WRITE setBookTitle NOTIFY bookTitleChanged)
    Q_PROPERTY(QString bookCover READ bookCover WRITE setBookCover NOTIFY bookCoverChanged)
    Q_PROPERTY(QVariantList books READ books WRITE setBooks NOTIFY booksChanged)
    Q_PROPERTY(bool fullscreen READ fullscreen WRITE setFullscreen NOTIFY fullscreenChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString bookDirectoryName READ bookDirectoryName NOTIFY bookDirectoryNameChanged)
    Q_PROPERTY(bool isDirty READ isDirty NOTIFY isDirtyChanged)

public:
    explicit BookSet(QObject *parent = nullptr) : QObject(parent) {}

    QString _bookDirectoryName = "";
    QString bookDirectoryName() const { return _bookDirectoryName; }
    Q_SIGNAL void bookDirectoryNameChanged();

    // Crash-safe save state
    bool _isLoading = false;
    bool _isDirty = false;
    QByteArray _lastSavedHash;

    bool isDirty() const { return _isDirty; }
    Q_INVOKABLE void markDirty() {
        if (!_isDirty) {
            _isDirty = true;
            emit isDirtyChanged();
        }
    }

    // Reliable, read-only "are there unsaved edits?" check for the UI to decide
    // whether to prompt on app close / book switch. Unlike the _isDirty flag
    // (which depends on explicit markDirty() calls scattered across the UI),
    // this mirrors exactly what saveToJson() does: serialize the in-memory
    // model and compare its hash to the last saved/loaded baseline. Never
    // touches disk. Returns false while a load is in progress or if
    // serialization fails (i.e. err on the side of "nothing to lose").
    Q_INVOKABLE bool hasUnsavedChanges() {
        if (_isLoading)
            return false;
        QJsonObject jsonObj;
        try {
            jsonObj = toJson();
        } catch (...) {
            return false;
        }
        if (jsonObj.isEmpty())
            return false;
        QByteArray jsonData = QJsonDocument(jsonObj).toJson();
        QByteArray newHash = QCryptographicHash::hash(jsonData, QCryptographicHash::Md5);
        return newHash != _lastSavedHash;
    }

    // Re-anchor the "clean" baseline to the current in-memory state. Call this
    // once a freshly loaded book has fully settled (after QML bindings run), so
    // any non-user, load-time normalization (e.g. activities gaining default
    // image_coords) is folded into the baseline instead of being mistaken for
    // unsaved edits. Genuine user edits happen later and still flip the check.
    Q_INVOKABLE void resetBaseline() {
        if (_isLoading)
            return;
        QJsonObject jsonObj;
        try {
            jsonObj = toJson();
        } catch (...) {
            return;
        }
        if (jsonObj.isEmpty())
            return;
        _lastSavedHash = QCryptographicHash::hash(QJsonDocument(jsonObj).toJson(),
                                                  QCryptographicHash::Md5);
        if (_isDirty) {
            _isDirty = false;
            emit isDirtyChanged();
        }
    }

    bool initialize(const QString &config_path);

    // Return a copy of the serialized book with every drag&drop activity's word
    // pool shuffled. Applied ONLY to the bytes written to disk, so the saved
    // file never exposes the answer order, while the in-memory toJson() used for
    // change detection stays deterministic. Walks books→modules→pages→sections.
    static QJsonObject shuffleWordPoolsForDisk(QJsonObject root) {
        if (!root.contains("books"))
            return root;
        QJsonArray books = root["books"].toArray();
        for (int bi = 0; bi < books.size(); ++bi) {
            QJsonObject book = books[bi].toObject();
            QJsonArray modules = book["modules"].toArray();
            for (int mi = 0; mi < modules.size(); ++mi) {
                QJsonObject mod = modules[mi].toObject();
                QJsonArray pages = mod["pages"].toArray();
                for (int pi = 0; pi < pages.size(); ++pi) {
                    QJsonObject page = pages[pi].toObject();
                    QJsonArray sections = page["sections"].toArray();
                    for (int si = 0; si < sections.size(); ++si) {
                        QJsonObject sec = sections[si].toObject();
                        if (!sec.contains("activity"))
                            continue;
                        QJsonObject act = sec["activity"].toObject();
                        const QString t = act["type"].toString();
                        if ((t != "dragdroppicture" && t != "dragdroppicturegroup")
                                || !act.contains("words"))
                            continue;
                        QJsonArray w = act["words"].toArray();
                        for (int i = w.size() - 1; i > 0; --i) {
                            int j = QRandomGenerator::global()->bounded(i + 1);
                            QJsonValue tmp = w[i];
                            w[i] = w[j];
                            w[j] = tmp;
                        }
                        act["words"] = w;
                        sec["activity"] = act;
                        sections[si] = sec;
                    }
                    page["sections"] = sections;
                    pages[pi] = page;
                }
                mod["pages"] = pages;
                modules[mi] = mod;
            }
            book["modules"] = modules;
            books[bi] = book;
        }
        root["books"] = books;
        return root;
    }

    Q_INVOKABLE void saveToJson(bool fromAutoSave = false) {
        try {
            static QMutex mutex;
            QMutexLocker locker(&mutex);

            // Hard guard: never save while a load is in progress (transient state)
            if (_isLoading) {
                qWarning("saveToJson: skipped because a load is in progress");
                return;
            }

            QDir dir(_bookDirectoryName);
            if (!dir.exists()) {
                if (!dir.mkpath(".")) {
                    qWarning("Couldn't create directory: %s", qPrintable(_bookDirectoryName));
                    return;
                }
            }

            const QString filePath = _bookDirectoryName + "/config.json";
            const QString backupPath = filePath + ".bak";
            const QString safePath = filePath + ".bak.safe";

            // Build the new JSON
            QJsonObject jsonObj;
            try {
                jsonObj = toJson();
            } catch (...) {
                qCritical("saveToJson: exception during JSON serialization, aborting");
                return;
            }

            if (jsonObj.isEmpty()) {
                qWarning("saveToJson: serialized object is empty, aborting save");
                return;
            }

            QJsonDocument saveDoc(jsonObj);
            QByteArray jsonData = saveDoc.toJson();

            // Cheap no-op check: if content hash matches the last successful save,
            // skip without touching anything. Auto-save ticks short-circuit here.
            QByteArray newHash = QCryptographicHash::hash(jsonData, QCryptographicHash::Md5);
            if (newHash == _lastSavedHash) {
                if (_isDirty) {
                    _isDirty = false;
                    emit isDirtyChanged();
                }
                return;
            }

            // Catastrophic regression check vs. current on-disk file.
            // If books/modules collapsed to zero from a non-zero state, abort.
            bool regressionDetected = false;
            QFile prevFile(filePath);
            if (prevFile.exists() && prevFile.open(QIODevice::ReadOnly)) {
                QByteArray prevData = prevFile.readAll();
                prevFile.close();

                QJsonDocument prevDoc = QJsonDocument::fromJson(prevData);
                if (!prevDoc.isNull() && prevDoc.isObject()) {
                    QJsonObject prevRoot = prevDoc.object();
                    QJsonArray prevBooks = prevRoot["books"].toArray();
                    QJsonArray newBooks = jsonObj["books"].toArray();

                    if (prevBooks.size() > 0 && newBooks.size() == 0) {
                        regressionDetected = true;
                    } else {
                        int prevModules = 0, newModules = 0;
                        for (const QJsonValue &b : prevBooks)
                            prevModules += b.toObject()["modules"].toArray().size();
                        for (const QJsonValue &b : newBooks)
                            newModules += b.toObject()["modules"].toArray().size();

                        if (prevModules > 0 && newModules == 0) {
                            regressionDetected = true;
                        }
                    }
                }
            }

            if (regressionDetected) {
                qCritical("saveToJson: catastrophic regression detected (books/modules collapsed to 0). Aborting save without touching backups. autoSave=%d", fromAutoSave);
                return;
            }

            // Rotate primary backup: current config.json -> .bak
            if (QFile::exists(filePath)) {
                QFile::remove(backupPath);
                if (!QFile::copy(filePath, backupPath)) {
                    qWarning("Couldn't create backup file: %s", qPrintable(backupPath));
                    return;
                }
            }

            // The on-disk bytes get drag&drop word pools shuffled (answer-key
            // protection). Change detection above used the deterministic jsonData,
            // so this shuffle never makes the app look dirty.
            const QByteArray diskData =
                QJsonDocument(shuffleWordPoolsForDisk(jsonObj)).toJson();

            // Atomic write of new content via QSaveFile (temp + rename under the hood)
            QSaveFile saveFile(filePath);
            if (!saveFile.open(QIODevice::WriteOnly)) {
                qWarning("Couldn't open save file: %s", qPrintable(filePath));
                return;
            }
            if (saveFile.write(diskData) != diskData.size()) {
                qWarning("Failed to write complete data to save file");
                saveFile.cancelWriting();
                return;
            }
            if (!saveFile.commit()) {
                qWarning("Failed to commit save: %s", qPrintable(saveFile.errorString()));
                // Restore from backup if commit failed mid-way
                if (QFile::exists(backupPath) && !QFile::exists(filePath)) {
                    QFile::copy(backupPath, filePath);
                }
                return;
            }

            // Track last-successful state
            _lastSavedHash = newHash;
            if (_isDirty) {
                _isDirty = false;
                emit isDirtyChanged();
            }

            // Independent safety net: refresh .bak.safe at most once every 5 minutes.
            // This file survives 60-second auto-save churn and is the deepest recovery point.
            QFileInfo safeInfo(safePath);
            const qint64 fiveMinutes = 5 * 60;
            bool needSafe = !safeInfo.exists() ||
                            safeInfo.lastModified().secsTo(QDateTime::currentDateTime()) >= fiveMinutes;
            if (needSafe) {
                QFile::remove(safePath);
                QFile::copy(filePath, safePath);
            }
        } catch(const QException & ex) {
            qCritical() << "QException caught while saving:" << ex.what();
        } catch(const std::exception & ex) {
            qCritical() << "std::exception caught while saving:" << ex.what();
        } catch(...) {
            qCritical() << "Unknown exception caught while saving";
        }
    }

    QString _publisherName;
    QString _publisherLogoPath;
    QString _publisherFullLogoPath;
    QString _bookTitle;
    QString _bookCover;
    int _bookCount;
    QVector<Book*> _books;
    bool _fullscreen;
    QString _language;

    int bookCount() const { return _bookCount; }
    void setBookCount(int bookCount) {
        if (_bookCount != bookCount) {
            _bookCount = bookCount;
            emit bookCountChanged();
        }
    }

    QString publisherName() const { return _publisherName; }
    void setPublisherName(const QString &publisherName) {
        if (_publisherName != publisherName) {
            _publisherName = publisherName;
            emit publisherNameChanged();
        }
    }

    QString publisherLogoPath() const { return _publisherLogoPath; }
    void setPublisherLogoPath(const QString &publisherLogoPath) {
        if (_publisherLogoPath != publisherLogoPath) {
            _publisherLogoPath = publisherLogoPath;
            emit publisherLogoPathChanged();
        }
    }

    QString publisherFullLogoPath() const { return _publisherFullLogoPath; }
    void setPublisherFullLogoPath(const QString &publisherFullLogoPath) {
        if (_publisherFullLogoPath != publisherFullLogoPath) {
            _publisherFullLogoPath = publisherFullLogoPath;
            emit publisherFullLogoPathChanged();
        }
    }

    QString bookTitle() const { return _bookTitle; }
    void setBookTitle(const QString &bookTitle) {
        if (_bookTitle != bookTitle) {
            _bookTitle = bookTitle;
            emit bookTitleChanged();
        }
    }

    QString bookCover() const { return _bookCover; }
    void setBookCover(const QString &bookCover) {
        if (_bookCover != bookCover) {
            _bookCover = bookCover;
            emit bookCoverChanged();
        }
    }

    QVariantList books() const {
        QVariantList l;
        for (Book *b : _books) {
            l << QVariant::fromValue(b);
        }
        return l;
    }
    void setBooks(const QVariantList &books) {
        _books.clear();
        for (const QVariant &b : books) {
            Book *book = qobject_cast<Book*>(b.value<QObject*>());
            if (book) {
                _books.append(book);
            }
        }
        emit booksChanged();
    }

    bool fullscreen() const { return _fullscreen; }
    void setFullscreen(bool fullscreen) {
        if (_fullscreen != fullscreen) {
            _fullscreen = fullscreen;
            emit fullscreenChanged();
        }
    }

    QString language() const { return _language; }
    void setLanguage(const QString &language) {
        if (_language != language) {
            _language = language;
            emit languageChanged();
        }
    }

    QJsonObject toJson() const {
        QJsonObject root;
        root["publisher_name"] = _publisherName;
        root["publisher_logo_path"] = _publisherLogoPath;
        root["publisher_full_logo_path"] = _publisherFullLogoPath;
        root["fullscreen"] = _fullscreen;
        root["book_title"] = _bookTitle;
        root["book_cover"] = _bookCover;
        root["language"] = _language;

        QJsonArray booksArray;
        for (const Book *book : _books) {
            if (book) { // Null check eklendi
                booksArray.append(book->toJson());
            }
        }
        root["books"] = booksArray;

        return root;
    }

private:
    QVector<Module *> handleBooksModules(const QJsonArray &doc);
    QVector<Subtitles*> getSubtitles(QString videoPath);

signals:
    void bookCountChanged();
    void publisherNameChanged();
    void publisherLogoPathChanged();
    void publisherFullLogoPathChanged();
    void bookTitleChanged();
    void bookCoverChanged();
    void booksChanged();
    void fullscreenChanged();
    void languageChanged();
    void isDirtyChanged();

};

struct ConfigParser : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList bookSets READ bookSets WRITE setBookSets NOTIFY bookSetsChanged)
    Q_PROPERTY(QString hostname READ hostname WRITE setHostname NOTIFY hostnameChanged)
    Q_PROPERTY(QString publisherName READ publisherName WRITE setPublisherName NOTIFY publisherNameChanged)
    Q_PROPERTY(QString bookTitle READ bookTitle WRITE setBookTitle NOTIFY bookTitleChanged)
    Q_PROPERTY(QString firstRunDate READ firstRunDate WRITE setFirstRunDate NOTIFY firstRunDateChanged)
    // Remote kill switch: set by the /api/helpers heartbeat response and
    // persisted, so a server can lock this editor install. READ-only from QML;
    // change it via updateLockStatus().
    Q_PROPERTY(bool isLocked READ isLocked NOTIFY isLockedChanged)
    Q_PROPERTY(QStringList recentProject READ recentProject WRITE setRecentProject NOTIFY recentProjectChanged FINAL)


public:
    static ConfigParser* instance() {
        static ConfigParser* instance = new ConfigParser();
        return instance;
    }

    Q_INVOKABLE void refresh() {
        initialize();
        // const QUrl url(u"qrc:/qml/main.qml"_qs);
        // m_engine->load(url);

    }

    explicit ConfigParser(QObject *parent = nullptr);

    Q_INVOKABLE bool initialize(bool isFromFileSystem = false, const QString& path = "");

    Q_INVOKABLE void refreshRecentProjects();

    // Lists the audio/video files in the current book's media folder and
    // returns their absolute paths. Uses QDir so it works cross-platform and
    // resolves any ".." in the app/project path (which trips up QML's
    // FolderListModel). QML converts these to ./books/... relative paths via
    // findBooksFolder() and auditions them with "file:" + appPath + rel.
    Q_INVOKABLE QStringList listBookMedia(const QString &kind) const {
        QStringList out;
        if (_bookSets.isEmpty())
            return out;
        BookSet *bs = _bookSets.first();
        if (!bs)
            return out;
        QDir dir(bs->bookDirectoryName() + "/" + kind);
        if (!dir.exists())
            return out;
        const QStringList filters = (kind == QLatin1String("audio"))
            ? QStringList{ "*.mp3", "*.wav", "*.m4a", "*.aac", "*.ogg" }
            : QStringList{ "*.mp4", "*.mov", "*.m4v", "*.webm" };
        dir.setNameFilters(filters);
        dir.setFilter(QDir::Files);
        dir.setSorting(QDir::Name | QDir::IgnoreCase);
        const QString base = dir.absolutePath();
        const QStringList files = dir.entryList();
        for (const QString &f : files)
            out << base + "/" + f;
        return out;
    }

    QVector<BookSet*> _bookSets;

    QVariantList bookSets() const {
        QVariantList l;
        for (BookSet *b : _bookSets) {
            l << QVariant::fromValue(b);
        }
        return l;
    }
    void setBookSets(const QVariantList &bookSets) {
        _bookSets.clear();
        for (const QVariant &b : bookSets) {
            BookSet *bookSet = qobject_cast<BookSet*>(b.value<QObject*>());
            if (bookSet) {
                _bookSets.append(bookSet);
            }
        }
        emit bookSetsChanged();
    }
    QString getInformation(BookSet *bset);
    QJsonObject readEncryptedJsonFromFile();
    QString decryptData(const QByteArray &byteArray, const QByteArray &key);
    void saveEncryptedJsonToFile(const QString &jsonString);
    // Apply a lock state from the heartbeat: persist it and notify QML. The
    // server is authoritative — locked:true covers the app, locked:false frees it.
    Q_INVOKABLE void updateLockStatus(bool locked);


private:
    QString _hostname;
    QString _publisher_name;
    QString _book_title;
    QString _first_run_date;
    bool _is_locked = false;
    QStringList _recentProject;
    QString _currentProjectPath;

    QString hostname() const { return _hostname; }
    void setHostname(const QString &hostname) {
        if (_hostname != hostname) {
            _hostname = hostname;
            emit hostnameChanged();
        }
    }

    QString publisherName() const { return _publisher_name; }
    void setPublisherName(const QString &publisherName) {
        if (_publisher_name != publisherName) {
            _publisher_name = publisherName;
            emit publisherNameChanged();
        }
    }

    QString bookTitle() const { return _book_title; }
    void setBookTitle(const QString &bookTitle) {
        if (_book_title != bookTitle) {
            _book_title = bookTitle;
            emit bookTitleChanged();
        }
    }

    QString firstRunDate() const { return _first_run_date; }
    void setFirstRunDate(const QString &firstRunDate) {
        if (_first_run_date != firstRunDate) {
            _first_run_date = firstRunDate;
            emit firstRunDateChanged();
        }
    }

    bool isLocked() const { return _is_locked; }

public:
    void setEngine(QQmlApplicationEngine *engine) { m_engine = engine; }

    QStringList recentProject() const;
    void setRecentProject(const QStringList &newRecentProject);

    QString currentProjectName() const;
    void setCurrentProjectName(const QString &newCurrentProjectName);

signals:
    void bookSetsChanged();
    void hostnameChanged();
    void publisherNameChanged();
    void bookTitleChanged();
    void firstRunDateChanged();
    void isLockedChanged();

    void recentProjectChanged();


private:
    QQmlApplicationEngine* m_engine;
};
#endif // CONFIGPARSER_H
