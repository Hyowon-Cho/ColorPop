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

class _ColorPopGameState extends State<ColorPopGame> with TickerProviderStateMixin {
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
  
  late AnimationController popAnimationController;
  late AnimationController fallAnimationController;
  Map<String, Animation<double>> blockAnimations = {};

  @override
  void initState() {
    super.initState();
    
    popAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    fallAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
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

    // 블록 터지는 애니메이션 설정
    for (var block in blocks) {
      final key = '${block[0]},${block[1]}';
      blockAnimations[key] = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: popAnimationController,
          curve: Curves.easeOut,
        ),
      );
    }

    // 애니메이션 시작
    popAnimationController.forward(from: 0).then((_) {
      setState(() {
        // 블록 제거
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

        // 중력 효과 애니메이션 적용
        _applyGravityWithAnimation();
      });
    });
  }

    void _applyGravityWithAnimation() {
    // 기존 보드를 복사하여 새 보드 생성
    List<List<Color>> newBoard = List.generate(
      rows,
      (i) => List.generate(cols, (j) => board[i][j]),  // 기존 보드의 상태를 복사
    );

    // 각 열에 대해 처리
    for (int col = 0; col < cols; col++) {
      List<Color> column = [];
      
      // 남아있는 블록들 수집
      for (int row = rows - 1; row >= 0; row--) {
        if (board[row][col] != Colors.transparent) {
          column.add(board[row][col]);
        }
      }
      
      // 빈 공간 채우기
      while (column.length < rows) {
        column.add(colors[Random().nextInt(colors.length)]);
      }

      // 블록 재배치
      int newRow = rows - 1;
      for (Color color in column) {
        final key = '$newRow,$col';
        if (board[newRow][col] == Colors.transparent) {
          blockAnimations[key] = Tween<double>(
            begin: -1.0,
            end: 0.0,
          ).animate(
            CurvedAnimation(
              parent: fallAnimationController,
              curve: Curves.bounceOut,
            ),
          );
        }
        newBoard[newRow][col] = color;
        newRow--;
      }
    }

    // 애니메이션 시작
    fallAnimationController.forward(from: 0).then((_) {
      setState(() {
        board = newBoard;
        blockAnimations.clear();
      });
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
    popAnimationController.dispose();
    fallAnimationController.dispose();
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
                    child: AnimatedBuilder(  // 여기가 중요한 부분입니다
                      animation: Listenable.merge([
                        popAnimationController,
                        fallAnimationController,
                      ]),
                      builder: (context, child) {
                        final key = '$i,$j';
                        final popScale = blockAnimations[key]?.value ?? 1.0;
                        final fallOffset = blockAnimations[key]?.value ?? 0.0;

                        return Transform.translate(
                          offset: Offset(0, fallOffset * 40),  // 40은 블록의 높이
                          child: Transform.scale(
                            scale: popScale,
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
                        );
                      },
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
}}