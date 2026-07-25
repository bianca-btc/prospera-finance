import 'enums.dart';

/// Colaborador com acesso à base de dados compartilhada do Prospera.
/// Preparação para compartilhamento multi-usuário (Propietario/Editor/Visualizador).
class Collaborator {
  String id;
  String name;
  String email;
  ShareRole role;
  DateTime invitedAt;

  Collaborator({
    required this.id,
    required this.name,
    required this.email,
    this.role = ShareRole.visualizador,
    DateTime? invitedAt,
  }) : invitedAt = invitedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'invitedAt': invitedAt.toIso8601String(),
  };

  factory Collaborator.fromJson(Map<String, dynamic> json) => Collaborator(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: ShareRoleX.fromString(json['role'] as String? ?? 'visualizador'),
    invitedAt: json['invitedAt'] != null
        ? DateTime.parse(json['invitedAt'] as String)
        : DateTime.now(),
  );

  Collaborator copyWith({String? name, String? email, ShareRole? role}) {
    return Collaborator(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      invitedAt: invitedAt,
    );
  }
}
