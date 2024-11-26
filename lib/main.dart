import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const MaterialApp(home: ColorPopGame()));
}

class ColorPopGame extends StatefulWidget {
  const ColorPopGame({Key? key}) : super(key: key);

  @override
  State<ColorPopGame> createState() => _ColorPopGameState();
}

class _ColorPopGameState extends State<ColorPopGame> {
  static const int rows = 8;
  static const int cols = 8;
  late List<List<Color>> board;
  int score = 0;
  int remainingTime = 60;
  Timer? gameTimer;       
  bool isGameOver = false;
  int comboCount = 0;
  Timer? comboTimer;
  static const int comboTimeLimit = 5;
  int comboTimeRemaining = comboTimeLimit;

  final List<Color> colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
  ];
  
  

  @override
  void initState() {
    super.initState();
    initializeBoard();
    startTimer();
  }

  void initializeBoard() {
    final random = Random();
    board = List.generate(
      rows,
      (_) => List.generate(
        cols,
        (_) => colors[random.nextInt(colors.length)],
      ),
    );
  }
  

  bool isValidPosition(int row, int col) {
    return row >= 0 && row < rows && col >= 0 && col < cols;
  }

  List<List<int>> findConnectedBlocks(int row, int col, Color color) {
    List<List<int>> connected = [];
    Set<String> visited = {};

    void dfs(int r, int c) {
      if (!isValidPosition(r, c) ||
          visited.contains('$r,$c') ||
          board[r][c] != color) {
        return;
      }

      visited.add('$r,$c');
      connected.add([r, c]);

      // Check all 4 directions
      dfs(r - 1, c); // up
      dfs(r + 1, c); // down
      dfs(r, c - 1); // left
      dfs(r, c + 1); // right
    }

    dfs(row, col);
    return connected;
  }

  void popBlocks(List<List<int>> blocks) {
    if (blocks.length < 2) return;

    setState(() {
      
      for (var block in blocks) {
        int row = block[0];
        int col = block[1];
        board[row][col] = Colors.transparent;
      }

      comboCount++;
      startComboTimer();

      int baseScore = blocks.length * 10;
      int comboBonus = (comboCount - 1) * 5;
      score += baseScore + comboBonus;

      for (int col = 0; col < cols; col++) {
        List<Color> column = [];
        for (int row = rows - 1; row >= 0; row--) {
          if (board[row][col] != Colors.transparent) {
            column.add(board[row][col]);
          }
        }
        while (column.length < rows) {
          column.add(colors[Random().nextInt(colors.length)]);
        }
        for (int row = 0; row < rows; row++) {
          board[row][col] = column[rows - 1 - row];
        }
      }
    });
  }

  void startComboTimer() {
    comboTimer?.cancel();
    comboTimeRemaining = comboTimeLimit;
    
    comboTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (comboTimeRemaining > 0) {
          comboTimeRemaining--;
        } else {
          resetCombo();
        }
      });
    });
  }


  void resetCombo() {
    setState(() {
      comboCount = 0;
      comboTimeRemaining = comboTimeLimit;
      comboTimer?.cancel();
    });
  }


  void startTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          gameOver();
        }
      });
    });
  }
  


  void gameOver() {
    gameTimer?.cancel();
    setState(() {
      isGameOver = true;
    });
    showGameOverDialog();
  }


void showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Time\'s up!'),
            const SizedBox(height: 8),
            Text('Final Score: $score'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              resetGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void resetGame() {
    setState(() {
      score = 0;
      remainingTime = 60;
      isGameOver = false;
      resetCombo();
      initializeBoard();
      startTimer();
    });
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    comboTimer?.cancel();
    super.dispose();
  }


  Widget buildComboDisplay() {
    if (comboCount <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'COMBO x$comboCount',
            style: TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$comboTimeRemaining',
            style: TextStyle(
              color: Colors.purple.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [ 
            Text('Time: ${remainingTime}s'), 
            Text('Combo: $comboCount'),  
            Text('Score: $score'),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (remainingTime <= 10)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Time is running out!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            buildComboDisplay(),  
            for (int i = 0; i < rows; i++)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int j = 0; j < cols; j++)
                    GestureDetector(
                      onTap: isGameOver
                        ? null
                        : () {
                        var blocks = findConnectedBlocks(i, j, board[i][j]);
                        popBlocks(blocks);
                        },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: board[i][j],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: resetGame,
              child: const Text('Reset Game'),
            ),
          ],
        ),
      ),
    );
  }
}