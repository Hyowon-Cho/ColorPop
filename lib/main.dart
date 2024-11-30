import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

void main() {
  runApp(const MaterialApp(home: ColorPopGame()));
}

class ColorPopGame extends StatefulWidget {
  const ColorPopGame({Key? key}) : super(key: key);

  @override
  State<ColorPopGame> createState() => _ColorPopGameState();
}

enum GameMode {
  TIME_ATTACK,
  PUZZLE,
  INFINITE
}

extension GameModeExtension on GameMode {
  String get displayName {
    switch (this) {
      case GameMode.TIME_ATTACK:
        return 'Time Attack';
      case GameMode.PUZZLE:
        return 'Puzzle';
      case GameMode.INFINITE:
        return 'Infinite';
    }
  }
}


enum Difficulty {
  EASY,    
  NORMAL,  
  HARD
}
extension DifficultyExtension on Difficulty {
  String get displayName {
    switch (this) {
      case Difficulty.EASY:
        return 'Easy';
      case Difficulty.NORMAL:
        return 'Normal';
      case Difficulty.HARD:
        return 'Hard';
    }
  }
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
  int movesLeft = 30;  

  final AudioPlayer bgmPlayer = AudioPlayer();
  final AudioPlayer effectPlayer = AudioPlayer();
  final AudioPlayer comboPlayer = AudioPlayer();
  bool isSoundEnabled = true;


  ThemeMode themeMode = ThemeMode.light;
  

  GameMode currentMode = GameMode.TIME_ATTACK;
  Difficulty currentDifficulty = Difficulty.NORMAL;
  
  Map<Difficulty, Map<String, dynamic>> difficultySettings = {
    Difficulty.EASY: {
      'time': 90,
      'colors': 4,
      'moves': 40,  // Puzzle
      'scoreMultiplier': 1.5,  // infinite
    },
    Difficulty.NORMAL: {
      'time': 60,
      'colors': 5,
      'moves': 30,
      'scoreMultiplier': 1.0,
    },
    Difficulty.HARD: {
      'time': 45,
      'colors': 6,
      'moves': 20,
      'scoreMultiplier': 0.8,
    },
  };

  Map<GameMode, Map<String, dynamic>> gameModeSettings = {
    GameMode.TIME_ATTACK: {
      'hasTimeLimit': true,
      'description': 'Clear blocks before time runs out',
      'useTimer': true,
    },
    GameMode.PUZZLE: {
      'hasTimeLimit': false,
      'description': 'Clear the board with limited moves',
      'useMoves': true,
    },
    GameMode.INFINITE: {
      'hasTimeLimit': false,
      'description': 'Play endlessly with score multiplier',
      'useScoreMultiplier': true,
    },
  };

  final List<Color> defaultColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,  
  ];
  late List<Color> colors;  

  late AnimationController popAnimationController;
  late AnimationController fallAnimationController;
  Map<String, Animation<double>> blockAnimations = {};

  @override
  void initState() {
    super.initState();
    colors = defaultColors.take(difficultySettings[currentDifficulty]!['colors']).toList();
    
    popAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    fallAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    initializeBoard();
    startTimer();

    bgmPlayer.setReleaseMode(ReleaseMode.loop);
    playBGM();
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

    playPopSound();

    if (comboCount >= 2) {
      playComboSound();
    }

    if (currentMode == GameMode.PUZZLE) {
      if (movesLeft <= 0) return;  
      movesLeft--;  
    }

    // Popping blocks
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
      // Starting animation
    popAnimationController.forward(from: 0).then((_) {
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

        _applyGravityWithAnimation();
      });
    });
  }

    void _applyGravityWithAnimation() {
    List<List<Color>> newBoard = List.generate(
      rows,
      (i) => List.generate(cols, (j) => board[i][j]),
    );

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

  void playBGM() async {
    if (!isSoundEnabled) return;
    await bgmPlayer.play(AssetSource('audio/bgm.mp3'));
  }

  void playPopSound() async {
    if (!isSoundEnabled) return;
    await effectPlayer.play(AssetSource('audio/pop.mp3'));
  }

  void playComboSound() async {
    if (!isSoundEnabled) return;
    await comboPlayer.play(AssetSource('audio/combo.mp3'));
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
      isGameOver = false;
      resetCombo();
      
      switch (currentMode) {
        case GameMode.TIME_ATTACK:
          remainingTime = difficultySettings[currentDifficulty]!['time'];
          startTimer();
          break;
        case GameMode.PUZZLE:
          movesLeft = difficultySettings[currentDifficulty]!['moves'];
          gameTimer?.cancel();
          break;
        case GameMode.INFINITE:
          remainingTime = 0;  
          gameTimer?.cancel();
          break;
      }
      
      colors = List.generate(
        difficultySettings[currentDifficulty]!['colors'],
        (index) => defaultColors[index],
      );
      
      initializeBoard();
    });
  }


  void toggleTheme() {
  setState(() {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  });
}



  void updateScore(int baseScore) {
    setState(() {
      if (currentMode == GameMode.INFINITE) {
        double multiplier = difficultySettings[currentDifficulty]!['scoreMultiplier'];
        score += (baseScore * multiplier).round();
      } else {
        score += baseScore;
      }
    });
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    comboTimer?.cancel();
    popAnimationController.dispose();
    fallAnimationController.dispose();
    super.dispose();

    bgmPlayer.dispose();
    effectPlayer.dispose();
    comboPlayer.dispose();
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
          if (currentMode == GameMode.TIME_ATTACK)
            Text('Time: ${remainingTime}s')
          else if (currentMode == GameMode.PUZZLE)
            Text('Moves: $movesLeft')
          else
            Text('Infinite Mode'),
          Text('Combo: $comboCount'),
          Text('Score: $score'),
        ],
      ),
    ),
      endDrawer: Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Setting',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Game Mode'),
              subtitle: const Text('Select game mode'),
              trailing: DropdownButton<GameMode>(
                value: currentMode,
                onChanged: (GameMode? newValue) {
                  if (newValue != null) {
                    setState(() {
                      currentMode = newValue;
                      resetGame();
                    });
                  }
                },
                items: GameMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode.displayName),
                  );
                }).toList(),
              ),
            ),
            ListTile(
              title: const Text('Difficulty'),
              subtitle: const Text('Select difficulty level'),
              trailing: DropdownButton<Difficulty>(
                value: currentDifficulty,
                onChanged: (Difficulty? newValue) {
                  if (newValue != null) {
                    setState(() {
                      currentDifficulty = newValue;
                      remainingTime = difficultySettings[newValue]!['time'];
                      resetGame();
                    });
                  }
                },
                items: Difficulty.values.map((difficulty) {
                  return DropdownMenuItem(
                    value: difficulty,
                    child: Text(difficulty.displayName),
                  );
                }).toList(),
              ),
            ),
            const Divider(),  // 여기에 구분선 추가
            ListTile(
              title: const Text('Sound'),
              subtitle: const Text('Toggle sound effects'),
              trailing: IconButton(
                icon: Icon(
                  isSoundEnabled ? Icons.volume_up : Icons.volume_off,
                ),
                onPressed: () {
                  setState(() {
                    isSoundEnabled = !isSoundEnabled;
                    if (isSoundEnabled) {
                      playBGM();
                    } else {
                      bgmPlayer.stop();
                    }
                  });
                },
              ),
            ),
            const Divider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Settings:',
                      style: TextStyle(
                        fontSize: 24,  
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16), 
                    
                    Text(
                      'Mode: ${currentMode.displayName}',
                      style: TextStyle(fontSize: 20),  
                    ),
                    Text(
                      '${gameModeSettings[currentMode]!['description']}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),  
                    
                    Text(
                      'Difficulty: ${currentDifficulty.displayName}',
                      style: TextStyle(fontSize: 20),
                    ),
                    
                    if (currentMode == GameMode.TIME_ATTACK)
                      Text(
                        'Time Limit: ${difficultySettings[currentDifficulty]!['time']}s',
                        style: TextStyle(fontSize: 18),
                      )
                    else if (currentMode == GameMode.PUZZLE)
                      Text(
                        'Moves Limit: ${difficultySettings[currentDifficulty]!['moves']}',
                        style: TextStyle(fontSize: 18),
                      )
                    else if (currentMode == GameMode.INFINITE)
                      Text(
                        'Score Multiplier: x${difficultySettings[currentDifficulty]!['scoreMultiplier']}',
                        style: TextStyle(fontSize: 18),
                      ),
                    Text(
                      'Colors: ${difficultySettings[currentDifficulty]!['colors']}',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (remainingTime <= 10 && currentMode == GameMode.TIME_ATTACK)
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
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        popAnimationController,
                        fallAnimationController,
                      ]),
                      builder: (context, child) {
                        final key = '$i,$j';
                        final popScale = blockAnimations[key]?.value ?? 1.0;
                        final fallOffset = blockAnimations[key]?.value ?? 0.0;

                        return Transform.translate(
                          offset: Offset(0, fallOffset * 40),
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