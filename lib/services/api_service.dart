// ============================================================
// ARQUIVO: services/api_service.dart
// FUNÇÃO: Cliente HTTP centralizado para comunicação com a API
//         oficial do Papacapim (https://api.papacapim.just.pro.br).
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Exceção personalizada para encapsular erros retornados pela API.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Serviço responsável por todas as requisições HTTP da API Papacapim.
class ApiService {
  // Padrão Singleton para compartilhar a mesma instância e token de sessão no app todo.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // URL base da API oficial do Papacapim.
  static const String baseUrl = 'https://api.papacapim.just.pro.br';

  // Token de sessão retornado no login (enviado no header 'x-session-token').
  String? sessionToken;

  // Login do usuário autenticado atualmente.
  String? currentLogin;

  /// Retorna os cabeçalhos padrão para as requisições HTTP.
  Map<String, String> _headers({bool requiresAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    if (requiresAuth && sessionToken != null) {
      headers['x-session-token'] = sessionToken!;
    }
    return headers;
  }

  /// Trata a resposta da API, decodificando o JSON ou lançando uma [ApiException].
  dynamic _handleResponse(http.Response response) {
    // Resposta 204 No Content não possui corpo para decodificar.
    if (response.statusCode == 204) {
      return null;
    }

    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      String errorMessage = 'Erro na requisição (${response.statusCode})';
      if (body is Map) {
        if (body.containsKey('message')) {
          errorMessage = body['message'].toString();
        } else if (body.containsKey('error')) {
          errorMessage = body['error'].toString();
        } else {
          // Extrai e traduz erros de validação retornados pelo back-end (ex: {"login": ["has already been taken"]})
          final errorList = <String>[];
          body.forEach((field, msgs) {
            String fieldName = field.toString();
            if (fieldName == 'login') fieldName = 'Login';
            if (fieldName == 'name') fieldName = 'Nome';
            if (fieldName == 'password') fieldName = 'Senha';
            if (fieldName == 'password_confirmation') fieldName = 'Confirmação de Senha';

            if (msgs is List) {
              for (var m in msgs) {
                var text = m.toString();
                if (text.contains('has already been taken')) text = 'já está em uso';
                if (text.contains("can't be blank")) text = 'não pode ficar em branco';
                if (text.contains('is too short')) text = 'muito curto (mínimo 3 caracteres)';
                errorList.add('$fieldName $text');
              }
            } else if (msgs is String) {
              errorList.add('$fieldName: $msgs');
            }
          });
          if (errorList.isNotEmpty) {
            errorMessage = errorList.join(', ');
          }
        }
      }

      if (errorMessage == 'Erro na requisição (${response.statusCode})') {
        if (response.statusCode == 401) {
          errorMessage = 'Sessão inválida ou credenciais incorretas.';
        } else if (response.statusCode == 404) {
          errorMessage = 'Recurso não encontrado.';
        } else if (response.statusCode == 422) {
          errorMessage = 'Dados inválidos. Verifique as informações preenchidas.';
        }
      }
      throw ApiException(response.statusCode, errorMessage);
    }
  }

  // ============================================================
  // SEÇÃO: AUTENTICAÇÃO (Sessão & Cadastro)
  // ============================================================

  /// Realiza o login (POST /sessions) e armazena o token recebido.
  Future<Map<String, dynamic>> login(String login, String password) async {
    final url = Uri.parse('$baseUrl/sessions');
    final response = await http.post(
      url,
      headers: _headers(requiresAuth: false),
      body: jsonEncode({
        'login': login,
        'password': password,
      }),
    );

    final data = _handleResponse(response) as Map<String, dynamic>;
    sessionToken = data['token']?.toString();
    currentLogin = data['user_login']?.toString() ?? login;
    return data;
  }

  /// Encerra a sessão atual (DELETE /sessions/1).
  Future<void> logout() async {
    try {
      if (sessionToken != null) {
        final url = Uri.parse('$baseUrl/sessions/1');
        await http.delete(url, headers: _headers());
      }
    } finally {
      sessionToken = null;
      currentLogin = null;
    }
  }

  /// Cria um novo usuário na rede social (POST /users).
  Future<Map<String, dynamic>> register({
    required String name,
    required String login,
    required String password,
    required String passwordConfirmation,
  }) async {
    final url = Uri.parse('$baseUrl/users');
    final response = await http.post(
      url,
      headers: _headers(requiresAuth: false),
      body: jsonEncode({
        'name': name,
        'login': login,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    return _handleResponse(response) as Map<String, dynamic>;
  }

  // ============================================================
  // SEÇÃO: USUÁRIOS
  // ============================================================

  /// Obtém os dados de um usuário pelo login (GET /users/{login}).
  /// Passar 'me' busca o perfil do usuário logado.
  Future<Map<String, dynamic>> getUser(String login) async {
    final url = Uri.parse('$baseUrl/users/$login');
    final response = await http.get(url, headers: _headers());
    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Altera os dados do usuário logado (PATCH /users/me).
  Future<Map<String, dynamic>> updateUser({
    String? name,
    String? password,
    String? passwordConfirmation,
    String? imageDataBase64,
  }) async {
    final url = Uri.parse('$baseUrl/users/me');
    final userMap = <String, dynamic>{};

    if (name != null && name.isNotEmpty) userMap['name'] = name;
    if (password != null && password.isNotEmpty) {
      userMap['password'] = password;
      userMap['password_confirmation'] = passwordConfirmation ?? password;
    }
    if (imageDataBase64 != null && imageDataBase64.isNotEmpty) {
      userMap['image_data'] = imageDataBase64;
    }

    final response = await http.patch(
      url,
      headers: _headers(),
      body: jsonEncode({'user': userMap}),
    );

    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Exclui permanentemente a conta do usuário logado (DELETE /users/me).
  Future<void> deleteAccount() async {
    final url = Uri.parse('$baseUrl/users/me');
    await http.delete(url, headers: _headers());
    sessionToken = null;
    currentLogin = null;
  }

  /// Busca ou lista usuários (GET /users?search={query}&page={page}).
  Future<List<dynamic>> searchUsers({String? search, int? page}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse('$baseUrl/users').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(url, headers: _headers());
    final data = _handleResponse(response);
    return data is List ? data : [];
  }

  // ============================================================
  // SEÇÃO: SEGUIDORES (Follow / Unfollow)
  // ============================================================

  /// Começa a seguir um usuário (POST /users/{login}/followers).
  Future<void> followUser(String login) async {
    final url = Uri.parse('$baseUrl/users/$login/followers');
    final response = await http.post(url, headers: _headers());
    _handleResponse(response);
  }

  /// Deixa de seguir um usuário (DELETE /users/{login}/followers/me).
  Future<void> unfollowUser(String login) async {
    final url = Uri.parse('$baseUrl/users/$login/followers/me');
    final response = await http.delete(url, headers: _headers());
    _handleResponse(response);
  }

  /// Lista seguidores de um usuário (GET /users/{login}/followers).
  Future<List<dynamic>> getFollowers(String login) async {
    final url = Uri.parse('$baseUrl/users/$login/followers');
    final response = await http.get(url, headers: _headers());
    final data = _handleResponse(response);
    return data is List ? data : [];
  }

  // ============================================================
  // SEÇÃO: POSTAGENS & RESPOSTAS
  // ============================================================

  /// Lista as postagens (GET /posts).
  /// [feedOnly]: se true, envia feed=1 (apenas postagens dos perfis que o usuário segue).
  /// [search]: busca postagens por termo.
  Future<List<dynamic>> getPosts({bool feedOnly = false, String? search, int? page}) async {
    final queryParams = <String, String>{};
    if (feedOnly) queryParams['feed'] = '1';
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse('$baseUrl/posts').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(url, headers: _headers());
    final data = _handleResponse(response);
    return data is List ? data : [];
  }

  /// Lista postagens de um usuário específico (GET /users/{login}/posts).
  Future<List<dynamic>> getUserPosts(String login, {int? page}) async {
    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse('$baseUrl/users/$login/posts').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(url, headers: _headers());
    final data = _handleResponse(response);
    return data is List ? data : [];
  }

  /// Lista respostas a uma postagem (GET /posts/{id}/replies).
  Future<List<dynamic>> getPostReplies(dynamic postId, {int? page}) async {
    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse('$baseUrl/posts/$postId/replies').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(url, headers: _headers());
    final data = _handleResponse(response);
    return data is List ? data : [];
  }

  /// Cria uma nova postagem (POST /posts).
  Future<Map<String, dynamic>> createPost(String message, {String? base64Image}) async {
    final url = Uri.parse('$baseUrl/posts');
    final body = <String, dynamic>{'message': message};

    // Campo oficial da API para anexar imagens a uma postagem (POST /posts).
    if (base64Image != null && base64Image.isNotEmpty) {
      body['media'] = [
        {'medium_type': 'image', 'medium_data': base64Image}
      ];
    }

    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Responde a uma postagem existente (POST /posts/{id}/replies).
  Future<Map<String, dynamic>> replyPost(dynamic postId, String message) async {
    final url = Uri.parse('$baseUrl/posts/$postId/replies');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'reply': {'message': message}
      }),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Exclui uma postagem (DELETE /posts/{id}).
  Future<void> deletePost(dynamic postId) async {
    final url = Uri.parse('$baseUrl/posts/$postId');
    final response = await http.delete(url, headers: _headers());
    _handleResponse(response);
  }

  // ============================================================
  // SEÇÃO: CURTIDAS (Likes)
  // ============================================================

  /// Curte uma postagem (POST /posts/{id}/likes).
  Future<void> likePost(dynamic postId) async {
    final url = Uri.parse('$baseUrl/posts/$postId/likes');
    final response = await http.post(url, headers: _headers());
    _handleResponse(response);
  }

  /// Remove a curtida de uma postagem (DELETE /posts/{id}/likes/me).
  Future<void> unlikePost(dynamic postId) async {
    final url = Uri.parse('$baseUrl/posts/$postId/likes/me');
    final response = await http.delete(url, headers: _headers());
    _handleResponse(response);
  }
}