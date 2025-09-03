#include "gamesparser.h"
#include <QFile>
#include <QDir>
#include <QJsonParseError>
#include <QJsonObject>
#include <QJsonDocument>
#include <QGuiApplication>
#include <QDebug>
#include <QException>

GamesParser::GamesParser(QObject *parent) : QObject(parent) {
    // Constructor implementation
}

bool GamesParser::loadFromFile(const QString &filePath) {
    QString actualPath = filePath;
    
//     // If it's just a filename, construct the full path like ConfigParser does
//     if (!filePath.contains('/') && !filePath.contains('\\')) {
//         QString appDir = QGuiApplication::applicationDirPath();
// #ifdef Q_OS_MAC
//         appDir += "/../../../books/";
// #else
//         appDir += "/books/";
// #endif
        
//         // If we have a current project, use that specific book directory
//         if (!_currentProjectName.isEmpty()) {
//             actualPath = appDir + _currentProjectName + "/" + filePath;
//         } else {
//             actualPath = appDir + filePath;
//         }
//     }

    
    QFile file(actualPath + "/games.json");
    if (!file.exists()) {
        qWarning() << "Games file does not exist, creating:" << actualPath;

        if (!file.open(QIODevice::WriteOnly)) {
            qWarning() << "Could not create games file:" << actualPath;
            return false;
        }

        // İstersen başlangıç içeriği yazabilirsin:
        file.write("{}");  // Örneğin boş bir JSON
        file.close();
    }

    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Could not open games file:" << actualPath;
        return false;
    }
    qDebug() << "Games Path:" << actualPath;

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError) {
        qWarning() << "JSON parse error:" << error.errorString();
        return false;
    }

    _bookDirectoryName = filePath;

    fromJson(doc.object());
    return true;
}

bool GamesParser::saveToFile() {
    try {
        static QMutex mutex;
        QMutexLocker locker(&mutex);

        QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
        appDir += "/../../../books";
#else
        appDir += "/books";
#endif

        // Create directory if it doesn't exist
        QDir dir(_bookDirectoryName);
        if (!dir.exists()) {
            if (!dir.mkpath(".")) {
                qWarning("Couldn't create directory: %s", qPrintable(_bookDirectoryName));
                return false;
            }
        }

        QString filePath = _bookDirectoryName + "/games.json";
        QString tempFilePath = filePath + ".tmp";

        // First write to a temporary file
        QFile tempFile(tempFilePath);
        if (!tempFile.open(QIODevice::WriteOnly)) {
            qWarning("Couldn't open temporary file for writing: %s", qPrintable(tempFilePath));
            return false;
        }

        // CRASH-SAFE: JSON serialization with error checking
        QJsonObject jsonObj;
        try {
            jsonObj = toJson();
        } catch (...) {
            qCritical("Exception during JSON serialization in GamesParser");
            tempFile.close();
            QFile::remove(tempFilePath);
            return false;
        }
        
        if (jsonObj.isEmpty()) {
            qWarning("JSON object is empty, aborting save");
            tempFile.close();
            QFile::remove(tempFilePath);
            return false;
        }

        QJsonDocument saveDoc(jsonObj);
        QByteArray jsonData = saveDoc.toJson();

        // Write to temporary file
        if (tempFile.write(jsonData) != jsonData.size()) {
            qWarning("Failed to write complete data to temporary file");
            tempFile.close();
            QFile::remove(tempFilePath);
            return false;
        }

        // Ensure all data is written to disk
        tempFile.flush();
        tempFile.close();

        // Create backup of existing file if it exists
        QFile existingFile(filePath);
        if (existingFile.exists()) {
            QString backupPath = filePath + ".bak";
            QFile::remove(backupPath);
            if (!QFile::copy(filePath, backupPath)) {
                qWarning("Couldn't create backup file: %s", qPrintable(backupPath));
                QFile::remove(tempFilePath);
                return false;
            }
        }

        // Replace the original file with the temporary file
        if (!QFile::remove(filePath)) {
            qWarning("Couldn't remove original file: %s", qPrintable(filePath));
            QFile::remove(tempFilePath);
            return false;
        }

        if (!QFile::rename(tempFilePath, filePath)) {
            qWarning("Couldn't rename temporary file to original: %s", qPrintable(filePath));
            // Try to restore from backup
            if (QFile::exists(filePath + ".bak")) {
                QFile::copy(filePath + ".bak", filePath);
            }
            return false;
        }


        // Verify the written data
        QFile verifyFile(filePath);
        if (verifyFile.open(QIODevice::ReadOnly)) {
            QByteArray verifyData = verifyFile.readAll();
            verifyFile.close();

            if (verifyData != jsonData) {
                qWarning("Data verification failed, restoring backup");
                QFile::remove(filePath);
                QFile::copy(filePath + ".bak", filePath);
            }
        }
    } catch(const QException & ex) {
        qCritical() << "QException caught while saving games:" << ex.what();
        return false;
    } catch(const std::exception & ex) {
        qCritical() << "std::exception caught while saving games:" << ex.what();
        return false;
    } catch(...) {
        qCritical() << "Unknown exception caught while saving games";
        return false;
    }
    return true;
}

QJsonObject GamesParser::toJson() const {
    QJsonObject obj;
    
    if (!_levels.isEmpty()) {
        QJsonArray levelsArray;
        for (const Level *level : _levels) {
            if (level) { // Null check eklendi
                levelsArray.append(level->toJson());
            }
        }
        obj["levels"] = levelsArray;
    }
    
    return obj;
}

void GamesParser::fromJson(const QJsonObject &obj) {
    QJsonArray levelsArray = obj["levels"].toArray();
    
    // Clear existing levels
    qDeleteAll(_levels);
    _levels.clear();
    
    for (const QJsonValue &value : levelsArray) {
        Level *level = new Level(this);
        level->fromJson(value.toObject());
        _levels.append(level);
    }
    
    emit levelsChanged();
}

Level* GamesParser::createLevel(int levelNumber, const QString &title) {
    Level *level = new Level(this);
    level->setLevel(levelNumber);
    level->setTitle(title);
    _levels.append(level);
    emit levelsChanged();
    return level;
}

// Factory methods for creating specific game types
QuizGame* GamesParser::createQuizGame() {
    QuizGame *game = new QuizGame(this); // Parent set edildi
    // Initialize with empty questions array
    emit game->questionsChanged();
    return game;
}

MemoryGame* GamesParser::createMemoryGame() {
    MemoryGame *game = new MemoryGame(this); // Parent set edildi
    // Initialize with empty questions array
    emit game->questionsChanged();
    return game;
}

OrderGame* GamesParser::createOrderGame() {
    OrderGame *game = new OrderGame(this); // Parent set edildi
    // Initialize with empty questions array
    emit game->questionsChanged();
    return game;
}

SelectorGame* GamesParser::createSelectorGame() {
    SelectorGame *game = new SelectorGame(this); // Parent set edildi
    // Initialize with empty questions array
    emit game->questionsChanged();
    return game;
}

BuilderGame* GamesParser::createBuilderGame() {
    BuilderGame *game = new BuilderGame(this); // Parent set edildi
    // Initialize with empty questions array
    emit game->questionsChanged();
    return game;
}

CrosspuzzleGame* GamesParser::createCrosspuzzleGame() {
    CrosspuzzleGame *game = new CrosspuzzleGame(this); // Parent set edildi
    // Initialize with empty questions array
    emit game->questionsChanged();
    return game;
}

RaceGame* GamesParser::createRaceGame() {
    RaceGame *game = new RaceGame(this); // Parent set edildi
    // Initialize with empty questions array
    emit game->questionsChanged();
    return game;
}

// Methods for managing quiz questions and answers
QuizAnswer* GamesParser::createQuizAnswer(const QString &text, bool isCorrect) {
    QuizAnswer *answer = new QuizAnswer(this); // Parent set edildi
    answer->setText(text);
    answer->setIsCorrect(isCorrect);
    return answer;
}

QuizQuestion* GamesParser::createQuizQuestion(const QString &question, const QString &image) {
    QuizQuestion *quizQuestion = new QuizQuestion(this); // Parent set edildi
    quizQuestion->setQuestion(question);
    quizQuestion->setImage(image);
    
    // Create default 3 answers with parent
    QuizAnswer *answer1 = new QuizAnswer(quizQuestion);
    answer1->setText("");
    answer1->setIsCorrect(false);
    
    QuizAnswer *answer2 = new QuizAnswer(quizQuestion);
    answer2->setText("");
    answer2->setIsCorrect(false);
    
    QuizAnswer *answer3 = new QuizAnswer(quizQuestion);
    answer3->setText("");
    answer3->setIsCorrect(false);
    
    quizQuestion->_answers.append(answer1);
    quizQuestion->_answers.append(answer2);
    quizQuestion->_answers.append(answer3);
    
    emit quizQuestion->answersChanged();
    return quizQuestion;
}

void GamesParser::addQuestionToGame(QuizGame* game, QuizQuestion* question) {
    if (game && question) {
        game->_questions.append(question);
        emit game->questionsChanged();
    }
}

void GamesParser::removeQuestionFromGame(QuizGame* game, int index) {
    if (game && index >= 0 && index < game->_questions.size()) {
        QuizQuestion* question = game->_questions.takeAt(index);
        if (question) {
            question->deleteLater();
        }
        emit game->questionsChanged();
    }
}

void GamesParser::addAnswerToQuestion(QuizQuestion* question, QuizAnswer* answer) {
    if (question && answer) {
        question->_answers.append(answer);
        emit question->answersChanged();
    }
}

void GamesParser::removeAnswerFromQuestion(QuizQuestion* question, int index) {
    if (question && index >= 0 && index < question->_answers.size()) {
        QuizAnswer* answer = question->_answers.takeAt(index);
        if (answer) {
            answer->deleteLater();
        }
        emit question->answersChanged();
    }
}

// Methods for managing memory questions
MemoryQuestion* GamesParser::createMemoryQuestion(const QString &image, const QString &audio) {
    MemoryQuestion *memoryQuestion = new MemoryQuestion(this); // Parent set edildi
    memoryQuestion->setImage(image);
    memoryQuestion->setAudio(audio);
    return memoryQuestion;
}

void GamesParser::addQuestionToMemoryGame(MemoryGame* game, MemoryQuestion* question) {
    if (game && question) {
        game->_questions.append(question);
        emit game->questionsChanged();
    }
}

void GamesParser::removeQuestionFromMemoryGame(MemoryGame* game, int index) {
    qDebug() << "removeQuestionFromMemoryGame called with index:" << index;
    if (game && index >= 0 && index < game->_questions.size()) {
        qDebug() << "Removing memory question at index" << index << "from" << game->_questions.size() << "questions";
        MemoryQuestion* question = game->_questions.takeAt(index);
        if (question) {
            question->deleteLater();
        }
        emit game->questionsChanged();
        qDebug() << "Memory question removed. New count:" << game->_questions.size();
    } else {
        qDebug() << "removeQuestionFromMemoryGame failed - game:" << (game ? "valid" : "null") 
                 << "index:" << index << "questions count:" << (game ? game->_questions.size() : -1);
    }
}

// Methods for managing order questions
OrderQuestion* GamesParser::createOrderQuestion(const QVariantList &words) {
    OrderQuestion *orderQuestion = new OrderQuestion(this); // Parent set edildi
    orderQuestion->setWords(words);
    return orderQuestion;
}

void GamesParser::addQuestionToOrderGame(OrderGame* game, OrderQuestion* question) {
    if (game && question) {
        game->_questions.append(question);
        emit game->questionsChanged();
    }
}

void GamesParser::removeQuestionFromOrderGame(OrderGame* game, int index) {
    qDebug() << "removeQuestionFromOrderGame called with index:" << index;
    if (game && index >= 0 && index < game->_questions.size()) {
        qDebug() << "Removing order question at index" << index << "from" << game->_questions.size() << "questions";
        OrderQuestion* question = game->_questions.takeAt(index);
        if (question) {
            question->deleteLater();
        }
        emit game->questionsChanged();
        qDebug() << "Order question removed. New count:" << game->_questions.size();
    } else {
        qDebug() << "removeQuestionFromOrderGame failed - game:" << (game ? "valid" : "null") 
                 << "index:" << index << "questions count:" << (game ? game->_questions.size() : -1);
    }
}

// Methods for managing selector questions and answers
SelectorAnswer* GamesParser::createSelectorAnswer(const QString &text, const QString &image, bool isCorrect) {
    SelectorAnswer *selectorAnswer = new SelectorAnswer(this); // Parent set edildi
    selectorAnswer->setText(text);
    selectorAnswer->setImage(image);
    selectorAnswer->setIsCorrect(isCorrect);
    return selectorAnswer;
}

SelectorQuestion* GamesParser::createSelectorQuestion(const QString &image, const QString &audio, const QString &video) {
    SelectorQuestion *selectorQuestion = new SelectorQuestion(this); // Parent set edildi
    selectorQuestion->setImage(image);
    selectorQuestion->setAudio(audio);
    selectorQuestion->setVideo(video);
    return selectorQuestion;
}

void GamesParser::addQuestionToSelectorGame(SelectorGame* game, SelectorQuestion* question) {
    if (game && question) {
        game->_questions.append(question);
        emit game->questionsChanged();
        qDebug() << "Selector question added. Total questions:" << game->_questions.size();
    }
}

void GamesParser::removeQuestionFromSelectorGame(SelectorGame* game, int index) {
    qDebug() << "removeQuestionFromSelectorGame called with index:" << index;
    if (game && index >= 0 && index < game->_questions.size()) {
        qDebug() << "Removing selector question at index" << index << "from" << game->_questions.size() << "questions";
        SelectorQuestion* question = game->_questions.takeAt(index);
        if (question) {
            question->deleteLater();
        }
        emit game->questionsChanged();
        qDebug() << "Selector question removed. New count:" << game->_questions.size();
    } else {
        qDebug() << "removeQuestionFromSelectorGame failed - game:" << (game ? "valid" : "null") 
                 << "index:" << index << "questions count:" << (game ? game->_questions.size() : -1);
    }
}

void GamesParser::addAnswerToSelectorQuestion(SelectorQuestion* question, SelectorAnswer* answer) {
    if (question && answer) {
        question->_answers.append(answer);
        emit question->answersChanged();
        qDebug() << "Selector answer added. Total answers:" << question->_answers.size();
    }
}

void GamesParser::removeAnswerFromSelectorQuestion(SelectorQuestion* question, int index) {
    if (question && index >= 0 && index < question->_answers.size()) {
        SelectorAnswer* answer = question->_answers.takeAt(index);
        if (answer) {
            answer->deleteLater();
        }
        emit question->answersChanged();
        qDebug() << "Selector answer removed. Total answers:" << question->_answers.size();
    }
}

// Methods for managing builder questions
BuilderQuestion* GamesParser::createBuilderQuestion(const QString &question, const QString &image, const QString &audio, const QString &video, const QVariantList &words) {
    BuilderQuestion *builderQuestion = new BuilderQuestion(this); // Parent set edildi
    builderQuestion->setQuestion(question);
    builderQuestion->setImage(image);
    builderQuestion->setAudio(audio);
    builderQuestion->setVideo(video);
    builderQuestion->setWords(words);
    return builderQuestion;
}

void GamesParser::addQuestionToBuilderGame(BuilderGame* game, BuilderQuestion* question) {
    if (game && question) {
        game->_questions.append(question);
        emit game->questionsChanged();
        qDebug() << "Builder question added. Total questions:" << game->_questions.size();
    }
}

void GamesParser::removeQuestionFromBuilderGame(BuilderGame* game, int index) {
    qDebug() << "removeQuestionFromBuilderGame called with index:" << index;
    if (game && index >= 0 && index < game->_questions.size()) {
        qDebug() << "Removing builder question at index" << index << "from" << game->_questions.size() << "questions";
        BuilderQuestion* question = game->_questions.takeAt(index);
        if (question) {
            question->deleteLater();
        }
        emit game->questionsChanged();
        qDebug() << "Builder question removed. New count:" << game->_questions.size();
    } else {
        qDebug() << "removeQuestionFromBuilderGame failed - game:" << (game ? "valid" : "null") 
                 << "index:" << index << "questions count:" << (game ? game->_questions.size() : -1);
    }
}

// Methods for managing crosspuzzle questions and answers
CrosspuzzleAnswer* GamesParser::createCrosspuzzleAnswer(const QString &text) {
    CrosspuzzleAnswer *crosspuzzleAnswer = new CrosspuzzleAnswer(this); // Parent set edildi
    crosspuzzleAnswer->setText(text);
    return crosspuzzleAnswer;
}

CrosspuzzleQuestion* GamesParser::createCrosspuzzleQuestion(const QString &question) {
    CrosspuzzleQuestion *crosspuzzleQuestion = new CrosspuzzleQuestion(this); // Parent set edildi
    crosspuzzleQuestion->setQuestion(question);
    return crosspuzzleQuestion;
}

void GamesParser::addQuestionToCrosspuzzleGame(CrosspuzzleGame* game, CrosspuzzleQuestion* question) {
    if (game && question) {
        game->_questions.append(question);
        emit game->questionsChanged();
        qDebug() << "Crosspuzzle question added. Total questions:" << game->_questions.size();
    }
}

void GamesParser::removeQuestionFromCrosspuzzleGame(CrosspuzzleGame* game, int index) {
    qDebug() << "removeQuestionFromCrosspuzzleGame called with index:" << index;
    if (game && index >= 0 && index < game->_questions.size()) {
        qDebug() << "Removing crosspuzzle question at index" << index << "from" << game->_questions.size() << "questions";
        CrosspuzzleQuestion* question = game->_questions.takeAt(index);
        if (question) {
            question->deleteLater();
        }
        emit game->questionsChanged();
        qDebug() << "Crosspuzzle question removed. New count:" << game->_questions.size();
    } else {
        qDebug() << "removeQuestionFromCrosspuzzleGame failed - game:" << (game ? "valid" : "null") 
                 << "index:" << index << "questions count:" << (game ? game->_questions.size() : -1);
    }
}

void GamesParser::addAnswerToCrosspuzzleQuestion(CrosspuzzleQuestion* question, CrosspuzzleAnswer* answer) {
    if (question && answer) {
        question->_answers.append(answer);
        emit question->answersChanged();
        qDebug() << "Crosspuzzle answer added. Total answers:" << question->_answers.size();
    }
}

void GamesParser::removeAnswerFromCrosspuzzleQuestion(CrosspuzzleQuestion* question, int index) {
    if (question && index >= 0 && index < question->_answers.size()) {
        CrosspuzzleAnswer* answer = question->_answers.takeAt(index);
        if (answer) {
            answer->deleteLater();
        }
        emit question->answersChanged();
        qDebug() << "Crosspuzzle answer removed. Total answers:" << question->_answers.size();
    }
}

// Methods for managing race questions and answers
RaceAnswer* GamesParser::createRaceAnswer(const QString &text, const QString &image, bool isCorrect) {
    RaceAnswer *raceAnswer = new RaceAnswer(this); // Parent set edildi
    raceAnswer->setText(text);
    raceAnswer->setImage(image);
    raceAnswer->setIsCorrect(isCorrect);
    return raceAnswer;
}

RaceQuestion* GamesParser::createRaceQuestion(const QString &question, const QString &image, const QString &audio) {
    RaceQuestion *raceQuestion = new RaceQuestion(this); // Parent set edildi
    raceQuestion->setQuestion(question);
    raceQuestion->setImage(image);
    raceQuestion->setAudio(audio);
    return raceQuestion;
}

void GamesParser::addQuestionToRaceGame(RaceGame* game, RaceQuestion* question) {
    if (game && question) {
        game->_questions.append(question);
        emit game->questionsChanged();
        qDebug() << "Race question added. Total questions:" << game->_questions.size();
    }
}

void GamesParser::removeQuestionFromRaceGame(RaceGame* game, int index) {
    qDebug() << "removeQuestionFromRaceGame called with index:" << index;
    if (game && index >= 0 && index < game->_questions.size()) {
        qDebug() << "Removing race question at index" << index << "from" << game->_questions.size() << "questions";
        RaceQuestion* question = game->_questions.takeAt(index);
        if (question) {
            question->deleteLater();
        }
        emit game->questionsChanged();
        qDebug() << "Race question removed. New count:" << game->_questions.size();
    } else {
        qDebug() << "removeQuestionFromRaceGame failed - game:" << (game ? "valid" : "null") 
                 << "index:" << index << "questions count:" << (game ? game->_questions.size() : -1);
    }
}

void GamesParser::addAnswerToRaceQuestion(RaceQuestion* question, RaceAnswer* answer) {
    if (question && answer) {
        question->_answers.append(answer);
        emit question->answersChanged();
        qDebug() << "Race answer added. Total answers:" << question->_answers.size();
    }
}

void GamesParser::removeAnswerFromRaceQuestion(RaceQuestion* question, int index) {
    if (question && index >= 0 && index < question->_answers.size()) {
        RaceAnswer* answer = question->_answers.takeAt(index);
        if (answer) {
            answer->deleteLater();
        }
        emit question->answersChanged();
        qDebug() << "Race answer removed from question at index:" << index;
    }
}

// Add games to level methods
void GamesParser::addQuizGameToLevel(Level* level, QuizGame* game) {
    if (level && game) {
        level->_quizGames.append(game);
        emit level->quizGamesChanged();
        qDebug() << "Quiz game added to level";
    }
}

void GamesParser::addRaceGameToLevel(Level* level, RaceGame* game) {
    if (level && game) {
        level->_raceGames.append(game);
        emit level->raceGamesChanged();
        qDebug() << "Race game added to level";
    }
}

void GamesParser::addMemoryGameToLevel(Level* level, MemoryGame* game) {
    if (level && game) {
        level->_memoryGames.append(game);
        emit level->memoryGamesChanged();
        qDebug() << "Memory game added to level";
    }
}

void GamesParser::addOrderGameToLevel(Level* level, OrderGame* game) {
    if (level && game) {
        level->_orderGames.append(game);
        emit level->orderGamesChanged();
        qDebug() << "Order game added to level";
    }
}

void GamesParser::addSelectorGameToLevel(Level* level, SelectorGame* game) {
    if (level && game) {
        level->_selectorGames.append(game);
        emit level->selectorGamesChanged();
        qDebug() << "Selector game added to level";
    }
}

void GamesParser::addBuilderGameToLevel(Level* level, BuilderGame* game) {
    if (level && game) {
        level->_builderGames.append(game);
        emit level->builderGamesChanged();
        qDebug() << "Builder game added to level";
    }
}

void GamesParser::addCrosspuzzleGameToLevel(Level* level, CrosspuzzleGame* game) {
    if (level && game) {
        level->_crosspuzzleGames.append(game);
        emit level->crosspuzzleGamesChanged();
        qDebug() << "Crosspuzzle game added to level";
    }
} 
