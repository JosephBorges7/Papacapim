// ============================================================
// ARQUIVO: models/post.dart
// FUNÇÃO: Modelo de dados de uma publicação integrado à API.
// ============================================================

import 'user.dart';

class Post {
  // Identificador único do post na API (imutável).
  final String id;

  // Login do usuário autor da postagem (compatível com Parte 1).
  final String userId;

  // Texto da publicação (campo 'message' na API).
  final String content;

  // Quantidade de curtidas (mutável).
  int likes;

  // Data e hora de criação do post.
  final DateTime createdAt;

  // ID do post original, caso esta publicação seja uma resposta ('post_id' na API).
  final String? parentPostId;

  // Quantidade de respostas ao post.
  int repliesCount;

  // Indica se o usuário autenticado curtiu esta postagem.
  bool youLiked;

  // Dados do autor do post (quando aninhados pela API).
  User? author;

  final String? apiImageUrl;

  // ── Construtor ──────────────────────────────────────────────
  Post({
    required this.id,
    required this.userId,
    required this.content,
    required this.likes,
    required this.createdAt,
    this.parentPostId,
    this.repliesCount = 0,
    this.youLiked = false,
    this.author,
    this.apiImageUrl,
  });

  // ── Construtor a partir do JSON da API Papacapim ────────────
  factory Post.fromJson(Map<String, dynamic> json) {
    User? parsedAuthor;
    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      parsedAuthor = User.fromJson(json['user'] as Map<String, dynamic>);
    }

    final rawUserId = parsedAuthor?.login ??
        json['user_id']?.toString() ??
        json['userId']?.toString() ??
        '';

    return Post(
      id: json['id']?.toString() ?? '',
      userId: rawUserId,
      content: json['message']?.toString() ?? json['content']?.toString() ?? '',
      likes: (json['likes_number'] as num?)?.toInt() ??
          (json['likes'] as num?)?.toInt() ??
          0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      parentPostId: json['post_id']?.toString() ?? json['parentPostId']?.toString(),
      repliesCount: (json['replies_number'] as num?)?.toInt() ?? 0,
      youLiked: json['you_liked'] == true,
      author: parsedAuthor,
      apiImageUrl: _extractMediaUrl(json['media']),
    );
  }

  static String? _extractMediaUrl(dynamic media) {
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map) {
        return first['url']?.toString() ??
            first['medium_data']?.toString() ??
            first['medium_url']?.toString();
      }
    }
    return null;
  }

  // ── Conversão do modelo para JSON ───────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'message': content,
      'likes_number': likes,
      'created_at': createdAt.toIso8601String(),
      'post_id': parentPostId,
      'replies_number': repliesCount,
      'you_liked': youLiked,
      if (author != null) 'user': author!.toJson(),
    };
  }
}
