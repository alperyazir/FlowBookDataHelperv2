
// Harfler
var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
var allWordsCoordinates = []
var words = [];

function getRandomColor() {
    var r = Math.floor(Math.random() * (250 - 75) + 75);
    var g = Math.floor(Math.random() * (250 - 75) + 75);
    var b = Math.floor(Math.random() * (250 - 75) + 75);

    // Opaklık değerini 0-255 aralığında hesapla
    var a = Math.floor(255);

    // Renk değerlerini iki haneli HEX formatında oluştur
    var hr = r.toString(16).padStart(2, '0');
    var hg = g.toString(16).padStart(2, '0');
    var hb = b.toString(16).padStart(2, '0');
    var ha = a.toString(16).padStart(2, '0');

    return '#' + hr + hg + hb;
}

function getRandomLetter() {
    return letters[Math.floor(Math.random() * letters.length)];
}

function placeWords(matrix, words) {
    var allCoordinates = [];
    for (var i = 0; i < words.length; i++) {
        var word = words[i].toUpperCase();
        var wordCoordinates = placeWord(matrix, word);
        allCoordinates.push(wordCoordinates);
    }
    return allCoordinates;
}

function placeWord(matrix, word) {
    var counter = 0
    while (true) {
        if (counter++> 50)
            break
        var direction = Math.floor(Math.random() * 2); // 0: yatay, 1: dikey, 2: çapraz
        var startX = 0
        var startY = 0
        var coordinates = [];
        if (direction === 0) {
            // Yatay
            startX = Math.floor(Math.random() * (15 - word.length));
            startY = Math.floor(Math.random() * 15);
            for (var i = 0; i < word.length; i++) {
                coordinates.push([startX + i, startY]);
            }
        } else if (direction === 1) {
            // Dikey
            startX = Math.floor(Math.random() * 15);
            startY = Math.floor(Math.random() * (15 - word.length));
            for (var i = 0; i < word.length; i++) {
                coordinates.push([startX, startY + i]);
            }
        } else {
            // Çapraz
            startX = Math.floor(Math.random() * (15 - word.length));
            startY = Math.floor(Math.random() * (15 - word.length));
            for (var i = 0; i < word.length; i++) {
                coordinates.push([startX + i, startY + i]);
            }
        }
        var found = true
        // Matrise kelimeyi yerleştir
        for (var i = 0; i < word.length; i++) {
            var x = coordinates[i][0];
            var y = coordinates[i][1];
            if (matrix[x][y] !== '-') {
                if (matrix[x][y] !== word[i]) {
                    found = false
                    break
                }
            }
        }
        if (found) {
            for (var i = 0; i < word.length; i++) {
                var x = coordinates[i][0];
                var y = coordinates[i][1];
                matrix[x][y] = word[i];
            }
            return coordinates;
        }
    }
}

function createMatrix() {
    var matrix = [];
    for (var i = 0; i < 15; i++) {
        var row = [];
        for (var j = 0; j < 15; j++) {
            row.push("-");
        }
        matrix.push(row);
    }
    return matrix;
}


function createPuzzleWithWords() {
    var matrix = createMatrix();
    var wordCoordinates = placeWords(matrix, words);
    return { "matrix": matrix, "wordCoordinates": wordCoordinates };
}


// Puzzle'ı yeniden oluşturmak için kullanılacak fonksiyon
function recreatePuzzle() {
    var puzzleData = createPuzzleWithWords();
    var puzzleMatrix = puzzleData.matrix;
    allWordsCoordinates = puzzleData.wordCoordinates;
    puzzleModel.clear();
    for (var i = 0; i < puzzleMatrix.length; i++) {
        var rowModel = [];
        for (var j = 0; j < puzzleMatrix[i].length; j++) {
            var isWord = true;
            if (puzzleMatrix[i][j] === "-") {
                isWord = false
                puzzleMatrix[i][j] = getRandomLetter()
            }
            rowModel.push({ "letter": puzzleMatrix[i][j], "isWord": isWord , "selected": false, "discovered": false, "color": "white"});
        }
        puzzleModel.append({ "rowModel": rowModel });
    }
}

function isCoordinateMatch(hist, coords) {
    const histStr = hist.map(coord => coord.toString());
    for (let i = 0; i < coords.length; i++) {
        const coordRow = coords[i];
        const coordRowStr = coordRow.map(coord => coord.toString());
        if (coordRowStr.length === histStr.length &&
                coordRowStr.every(coord => histStr.includes(coord))) {
            return true;
        }
    }
    return false;
}

