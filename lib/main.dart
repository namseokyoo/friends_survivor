import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
// import 'dart:io';
import 'dart:math' as math;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friends Survivor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? selectedImageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Friends Survivor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cursive',
                    ),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GameScreen(imageBytes: selectedImageBytes),
                        ),
                      );
                    },
                    child: const Text('게임 시작'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        final Uint8List imageBytes = await image.readAsBytes();
                        setState(() {
                          selectedImageBytes = imageBytes;
                        });
                      }
                    },
                    child: const Text('주인공 사진 적용'),
                  ),
                  if (selectedImageBytes != null) ...[
                    const SizedBox(height: 20),
                    ClipOval(
                      child: Image.memory(
                        selectedImageBytes!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// Enemy class
class Enemy {
  double x;
  double y;
  double speed;
  bool isActive;
  int health;

  Enemy({
    required this.x,
    required this.y,
    this.speed = 2.0,
    this.isActive = true,
    required this.health,
  });

  void moveTowardsPlayer(double playerX, double playerY) {
    final dx = playerX - x;
    final dy = playerY - y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > 0) {
      x += (dx / distance) * speed;
      y += (dy / distance) * speed;
    }
  }

  bool checkCollision(double playerX, double playerY) {
    final dx = playerX - x;
    final dy = playerY - y;
    final distance = math.sqrt(dx * dx + dy * dy);
    return distance < 40;
  }
}

// Projectile class
class Projectile {
  double x;
  double y;
  double speed;
  double angle;
  bool isActive;
  double power;

  Projectile({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    this.isActive = true,
    required this.power,
  });

  void move() {
    x += math.cos(angle) * speed;
    y += math.sin(angle) * speed;
  }

  bool checkCollision(Enemy enemy) {
    final dx = enemy.x + 15 - (x + 5);
    final dy = enemy.y + 15 - (y + 5);
    final distance = math.sqrt(dx * dx + dy * dy);
    final combinedRadius = 15 + 5;
    return distance < combinedRadius;
  }
}

// Experience Point 클래스 추가
class ExperiencePoint {
  final Offset position;
  final bool isTriple;
  final int value;

  Color get color => isTriple ? Colors.green : Colors.yellow;

  ExperiencePoint(this.position, this.isTriple) : value = isTriple ? 3 : 1;
}

class GameScreen extends StatefulWidget {
  final Uint8List? imageBytes;

  const GameScreen({super.key, this.imageBytes});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Player position and movement
  double playerX = 100.0;
  double playerY = 100.0;
  double velocityX = 0.0;
  double velocityY = 0.0;
  final double moveSpeed = 5.0;
  final double maxSpeed = 8.0;
  final double friction = 0.8;
  double playerHealth = 100.0;

  // Enemy management
  final List<Enemy> enemies = [];
  final math.Random random = math.Random();
  double spawnTimer = 0;
  double spawnInterval = 2.0; // 적이 발생하는 기본 간격 (초 단위)

  // Projectile management
  final List<Projectile> projectiles = [];

  // Key state tracking
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  // Animation controller for game loop
  late AnimationController _gameLoopController;

  // Experience management
  final List<ExperiencePoint> experiencePoints = [];
  int playerLevel = 1;
  int experienceCollected = 0;
  int experienceNeeded = 10;

  // Timer for automatic firing
  double fireTimer = 0;
  double fireInterval = 0.5;

  // Weapon upgrade options
  int projectileCount = 1;
  double projectilePower = 1.0;

  double maxPlayerHealth = 100.0;
  int upgradeCount = 0;
  double gameTime = 0.0;

  // Upgrade counts
  int fireRateUpgradeCount = 0;
  int projectileCountUpgradeCount = 0;
  int projectilePowerUpgradeCount = 0;

  // 게임 초기화 및 설정
  @override
  void initState() {
    super.initState();
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _gameLoopController.addListener(_gameLoop);
  }

  // 적 생성 함수
  void _spawnEnemy(Size screenSize) {
    double x, y;
    if (random.nextBool()) {
      x = random.nextBool() ? -50 : screenSize.width + 50;
      y = random.nextDouble() * screenSize.height;
    } else {
      x = random.nextDouble() * screenSize.width;
      y = random.nextBool() ? -50 : screenSize.height + 50;
    }
    int enemyHealth =
        3 + playerLevel * 2 + playerLevel; // Adjusted health with level
    enemies.add(Enemy(x: x, y: y, health: enemyHealth));
  }

  // 메인 게임 루프 - 매 프레임마다 실행
  void _gameLoop() {
    final size = MediaQuery.of(context).size;
    spawnTimer += 0.016;
    fireTimer += 0.016;
    gameTime += 0.016; // Increment game time

    // 50초마다 적 생성 간격 감소
    if (gameTime % 50 < 0.016) {
      // 50초마다 실행
      setState(() {
        spawnInterval = math.max(0.5, spawnInterval - 0.1); // 최소값 0.5 유지
      });
    }

    if (spawnTimer >= spawnInterval) {
      _spawnEnemy(size);
      spawnTimer = 0;
    }
    if (fireTimer >= fireInterval) {
      _fireProjectile();
      fireTimer = 0;
    }
    _updatePlayerPosition();
    _updateEnemies();
    _updateProjectiles();
    _checkCollisions();
    _checkExperienceCollection();
  }

  // 플레이어 위치 업데이트 및 이동 처리
  void _updatePlayerPosition() {
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      velocityX -= moveSpeed;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
      velocityX += moveSpeed;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      velocityY -= moveSpeed;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      velocityY += moveSpeed;
    }
    velocityX = velocityX.clamp(-maxSpeed, maxSpeed);
    velocityY = velocityY.clamp(-maxSpeed, maxSpeed);
    velocityX *= friction;
    velocityY *= friction;
    if (velocityX.abs() < 0.1) velocityX = 0;
    if (velocityY.abs() < 0.1) velocityY = 0;
    setState(() {
      playerX += velocityX;
      playerY += velocityY;
      playerX = playerX.clamp(0, MediaQuery.of(context).size.width - 50);
      playerY = playerY.clamp(0, MediaQuery.of(context).size.height - 50);
    });
  }

  // 적 위치 업데이트 및 관리
  void _updateEnemies() {
    for (var enemy in enemies) {
      if (enemy.isActive) {
        enemy.moveTowardsPlayer(playerX, playerY);
      }
    }
    enemies.removeWhere((enemy) => !enemy.isActive);
  }

  // 발사체 위치 업데이트 및 관리
  void _updateProjectiles() {
    for (var projectile in projectiles) {
      if (projectile.isActive) {
        projectile.move();
        if (projectile.x < 0 ||
            projectile.y < 0 ||
            projectile.x > MediaQuery.of(context).size.width ||
            projectile.y > MediaQuery.of(context).size.height) {
          projectile.isActive = false;
        }
      }
    }
    projectiles.removeWhere((projectile) => !projectile.isActive);
  }

  // 충돌 감지 (플레이어-적, 발사체-적)
  void _checkCollisions() {
    for (var enemy in enemies) {
      if (enemy.isActive && enemy.checkCollision(playerX, playerY)) {
        _handleCollision(enemy);
      }
      for (var projectile in projectiles) {
        if (projectile.isActive && projectile.checkCollision(enemy)) {
          setState(() {
            enemy.health -= projectile.power.toInt();
            projectile.isActive = false;
            if (enemy.health <= 0) {
              enemy.isActive = false;
              // 경험치 아이템 생성 로직
              final dropChance = random.nextDouble();
              if (dropChance < 0.1) {
                // 10% 확률로 녹색(3배) 경험치
                experiencePoints
                    .add(ExperiencePoint(Offset(enemy.x, enemy.y), true));
              } else if (dropChance < 0.8) {
                // 70% 확률로 노란색(1배) 경험치
                experiencePoints
                    .add(ExperiencePoint(Offset(enemy.x, enemy.y), false));
              }
            }
          });
        }
      }
    }
  }

  // 플레이어와 적 충돌 시 처리
  void _handleCollision(Enemy enemy) {
    setState(() {
      playerHealth -= 10;
      if (playerHealth <= 0) {
        _gameOver();
      }
    });
    final dx = playerX - enemy.x;
    final dy = playerY - enemy.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > 0) {
      velocityX += (dx / distance) * 15;
      velocityY += (dy / distance) * 15;
    }
  }

  // 발사체 생성 및 발사
  void _fireProjectile() {
    if (enemies.isEmpty) return;
    // Find the closest enemy
    Enemy? closestEnemy;
    double closestDistance = double.infinity;
    for (var enemy in enemies) {
      if (enemy.isActive) {
        final dx = enemy.x - playerX;
        final dy = enemy.y - playerY;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance < closestDistance) {
          closestDistance = distance;
          closestEnemy = enemy;
        }
      }
    }
    if (closestEnemy != null) {
      final dx = closestEnemy.x - playerX;
      final dy = closestEnemy.y - playerY;
      final angle = math.atan2(dy, dx);
      for (int i = 0; i < projectileCount; i++) {
        // 각 발사체에 약간의 각도 변화를 주어 퍼지게 함
        final spreadAngle = angle + (i - (projectileCount - 1) / 2) * 0.1;
        projectiles.add(Projectile(
          x: playerX,
          y: playerY,
          speed: 10.0,
          angle: spreadAngle,
          power: projectilePower,
        ));
      }
    }
  }

  // 경험치 아이템 수집 확인
  void _checkExperienceCollection() {
    experiencePoints.removeWhere((exp) {
      final dx = exp.position.dx - (playerX + 25);
      final dy = exp.position.dy - (playerY + 25);
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < 30) {
        experienceCollected += exp.value;
        if (experienceCollected >= experienceNeeded) {
          playerLevel++;
          experienceCollected = 0;
          experienceNeeded += 5;
          _showUpgradeOptions();
        }
        return true;
      }
      return false;
    });
  }

  // 레벨업 시 업그레이드 옵션 표시
  void _showUpgradeOptions() {
    _gameLoopController.stop(); // 게임 일시 중지
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('업그레이드 선택'),
        content: const Text('다음 중 하나를 선택하세요:'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                fireInterval = (fireInterval * 0.9).clamp(0.1, double.infinity);
                fireRateUpgradeCount++;
                upgradeCount++;
              });
              Navigator.of(context).pop();
              _gameLoopController.repeat(); // 게임 재개
            },
            child: const Text('발사 속도 증가'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                projectileCount++;
                projectileCountUpgradeCount++;
                upgradeCount++;
              });
              Navigator.of(context).pop();
              _gameLoopController.repeat(); // 게임 재개
            },
            child: const Text('발사 개수 증가'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                projectilePower += 1.0;
                projectilePowerUpgradeCount++;
                upgradeCount++;
              });
              Navigator.of(context).pop();
              _gameLoopController.repeat(); // 게임 재개
            },
            child: const Text('발사 파워 증가'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                playerHealth = maxPlayerHealth; // Fully heal to max health
                upgradeCount++;
              });
              Navigator.of(context).pop();
              _gameLoopController.repeat(); // 게임 재개
            },
            child: const Text('체력 회복'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                maxPlayerHealth += 5;
                playerHealth = (playerHealth + 5).clamp(
                    0, maxPlayerHealth); // Increase max health and heal by 5
                upgradeCount++;
              });
              Navigator.of(context).pop();
              _gameLoopController.repeat(); // 게임 재개
            },
            child: const Text('최대 체력 증가'),
          ),
        ],
      ),
    );
  }

  // 게임 오버 처리
  void _gameOver() {
    _gameLoopController.stop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('게임 오버'),
        content: const Text('다시 시도하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('재시작'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('홈으로'),
          ),
        ],
      ),
    );
  }

  // 게임 재시작
  void _restartGame() {
    setState(() {
      playerX = 100.0;
      playerY = 100.0;
      velocityX = 0.0;
      velocityY = 0.0;
      playerHealth = 100.0;
      enemies.clear();
      projectiles.clear();
      spawnTimer = 0;
    });
    _gameLoopController.repeat();
  }

  // 게임 일시정지
  void _pauseGame() {
    _gameLoopController.stop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('일시정지'),
        content: const Text('게임을 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _gameLoopController.repeat();
            },
            child: const Text('계속'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('재시작'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('홈으로'),
          ),
        ],
      ),
    );
  }

  // 리소스 정리
  @override
  void dispose() {
    _gameLoopController.dispose();
    super.dispose();
  }

  // UI 구성
  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          _pressedKeys.add(event.logicalKey);
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _fireProjectile();
          }
        } else if (event is RawKeyUpEvent) {
          _pressedKeys.remove(event.logicalKey);
        }
      },
      child: Scaffold(
        body: Container(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned(
                right: 10,
                top: 10,
                child: ElevatedButton(
                  onPressed: _pauseGame,
                  child: const Text('Pause'),
                ),
              ),
              Positioned(
                left: playerX,
                top: playerY,
                child: widget.imageBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          widget.imageBytes!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
              ...enemies.map((enemy) => Positioned(
                    left: enemy.x,
                    top: enemy.y,
                    child: Column(
                      children: [
                        Text(
                          '${enemy.health}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  )),
              ...projectiles.map((projectile) => Positioned(
                    left: projectile.x,
                    top: projectile.y,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )),
              ...experiencePoints.map((exp) => Positioned(
                    left: exp.position.dx,
                    top: exp.position.dy,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: exp.color,
                        shape: BoxShape.rectangle,
                      ),
                    ),
                  )),
              Positioned(
                top: 10,
                left: 10,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: playerHealth / 100,
                          backgroundColor: Colors.grey,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Text(
                      '${playerHealth.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 40,
                left: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enemies: ${enemies.where((enemy) => enemy.isActive).length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 5), // Consistent spacing
                    Text(
                      'Health: ${playerHealth.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 5), // Consistent spacing
                    Text(
                      'Level: $playerLevel',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 5), // Consistent spacing
                    Text(
                      'Experience: $experienceCollected/$experienceNeeded',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                left: MediaQuery.of(context).size.width / 2 - 50,
                child: Text(
                  '시간: ${gameTime.toInt()}초', // Display time as integer
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: Text(
                  '발사 속도 증가: $fireRateUpgradeCount\n'
                  '발사 개수 증가: $projectileCountUpgradeCount\n'
                  '발사 파워 증가: $projectilePowerUpgradeCount',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
