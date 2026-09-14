enum AuthProvider { email, google, apple }

class UserProfile {
  final String id;
  final String name;
  final String email;
  final AuthProvider authProvider;
  final int dailyGoalMinutes;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.authProvider,
    this.dailyGoalMinutes = 60,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'authProvider': authProvider.name,
        'dailyGoalMinutes': dailyGoalMinutes,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        authProvider: AuthProvider.values.firstWhere(
          (e) => e.name == map['authProvider'],
          orElse: () => AuthProvider.email,
        ),
        dailyGoalMinutes: (map['dailyGoalMinutes'] as num?)?.toInt() ?? 60,
      );
}
