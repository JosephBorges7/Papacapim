// ============================================================
// ARQUIVO: providers/app_state.dart
// FUNÇÃO: Gerencia o estado global do aplicativo conectado à
//         API oficial do Papacapim. Fornece métodos assíncronos
//         para autenticação, feeds, postagens e interações.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/post.dart';
import '../services/api_service.dart';

// ── Classe AppState ───────────────────────────────────────────
// Herda ChangeNotifier para notificar telas sobre mudanças de estado.
class AppState extends ChangeNotifier {
  // Instância do cliente HTTP da API
  final ApiService _api = ApiService();

  // ── Dados centrais do app ─────────────────────────────────────
  // Usuário autenticado no momento (null se deslogado).
  User? currentUser;

  // Listas de postagens carregadas da API
  List<Post> generalPosts = [];
  List<Post> followingPosts = [];

  // Cache local de usuários por login para acesso rápido
  final Map<String, User> _userCache = {};

  // Imagens anexadas às postagens (id do post -> imagem em Base64).
  final Map<String, String> postImages = {};

  // Estado de carregamento do feed
  bool isLoadingFeeds = false;

  // Mensagem de último erro ocorrido
  String? lastErrorMessage;

  // ============================================================
  // SEÇÃO: AUTENTICAÇÃO (Login, Logout, Cadastro)
  // ============================================================

  // ── Login ─────────────────────────────────────────────────────
  // Tenta autenticar o usuário na API com login e senha.
  // Retorna true em caso de sucesso.
  Future<bool> login(String username, String password) async {
    lastErrorMessage = null;
    try {
      // 1. Cria a sessão na API (POST /sessions)
      await _api.login(username, password);

      // 2. Busca os dados do perfil do usuário logado (GET /users/me ou GET /users/{login})
      final userData = await _api.getUser(username);
      currentUser = User.fromJson(userData);
      currentUser!.password = password; // Armazena localmente para formulários de edição
      _userCache[currentUser!.login] = currentUser!;

      // 3. Carrega os feeds iniciais
      await fetchFeeds();

      notifyListeners();
      return true; // Sucesso
    } catch (e) {
      lastErrorMessage = e.toString();
      notifyListeners();
      return false; // Falha na autenticação
    }
  }

  // ── Logout ────────────────────────────────────────────────────
  // Encerra a sessão atual na API e limpa os dados locais.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}

    currentUser = null;
    generalPosts = [];
    followingPosts = [];
    _userCache.clear();
    notifyListeners();
  }

  // ── Cadastro ──────────────────────────────────────────────────
  // Registra um novo usuário no back-end (POST /users) e faz login automático.
  Future<bool> register(
    String name,
    String username,
    String password, {
    String? passwordConfirmation,
  }) async {
    lastErrorMessage = null;
    try {
      // 1. Cria a conta no back-end
      await _api.register(
        name: name,
        login: username,
        password: password,
        passwordConfirmation: passwordConfirmation ?? password,
      );

      // 2. Realiza o login automaticamente
      return await login(username, password);
    } catch (e) {
      lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // SEÇÃO: FEEDS E POSTAGENS (Carregar, Criar, Deletar, Curtir)
  // ============================================================

  // ── Carregar todos os feeds (Geral e Seguindo) ─────────────────
  Future<void> fetchFeeds() async {
    isLoadingFeeds = true;
    notifyListeners();

    try {
      await Future.wait([
        fetchGeneralPosts(),
        fetchFollowingPosts(),
      ]);
    } catch (e) {
      lastErrorMessage = e.toString();
    } finally {
      isLoadingFeeds = false;
      notifyListeners();
    }
  }

  // ── Feed Geral (GET /posts) ──────────────────────────────────
  Future<void> fetchGeneralPosts() async {
    try {
      final data = await _api.getPosts(feedOnly: false);
      generalPosts = data.map((item) {
        final p = Post.fromJson(item as Map<String, dynamic>);
        if (p.author != null) {
          _userCache[p.author!.login] = p.author!;
        }
        return p;
      }).toList();
      notifyListeners();
    } catch (e) {
      lastErrorMessage = e.toString();
    }
  }

  // ── Feed Seguindo (GET /posts?feed=1) ─────────────────────────
  Future<void> fetchFollowingPosts() async {
    try {
      final data = await _api.getPosts(feedOnly: true);
      followingPosts = data.map((item) {
        final p = Post.fromJson(item as Map<String, dynamic>);
        if (p.author != null) {
          _userCache[p.author!.login] = p.author!;
        }
        return p;
      }).toList();
      notifyListeners();
    } catch (e) {
      lastErrorMessage = e.toString();
    }
  }

  // ── Criar post ou resposta ────────────────────────────────────
  // Envia POST /posts ou POST /posts/{id}/replies para o back-end.
  Future<bool> createPost(String content, {String? parentPostId, String? base64Image}) async {
    if (currentUser == null) return false;

    try {
      Map<String, dynamic> created;

      if (parentPostId != null && parentPostId.isNotEmpty) {
        created = await _api.replyPost(parentPostId, content);
      } else {
        // Envia pelo campo oficial "media" da API (POST /posts).
        created = await _api.createPost(content, base64Image: base64Image);
      }
      
      if (base64Image != null && base64Image.isNotEmpty) {
        final newId = created['id']?.toString();
        if (newId != null && newId.isNotEmpty) {
          postImages[newId] = base64Image;
        }
      }

      // Recarrega os feeds para refletir a nova postagem no topo
      await fetchFeeds();
      return true;
    } catch (e) {
      lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Deletar post ──────────────────────────────────────────────
  // Remove a postagem no back-end (DELETE /posts/{id}).
  Future<bool> deletePost(String postId) async {
    try {
      await _api.deletePost(postId);
      generalPosts.removeWhere((p) => p.id == postId);
      followingPosts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Curtir / Descurtir post ───────────────────────────────────
  // Alterna o status de curtida no back-end com atualização otimista na UI.
  Future<void> toggleLike(String postId) async {
    // Localiza o post nas listas
    Post? targetPost;
    for (final p in [...generalPosts, ...followingPosts]) {
      if (p.id == postId) {
        targetPost = p;
        break;
      }
    }

    if (targetPost == null) return;

    final wasLiked = targetPost.youLiked;
    final previousLikes = targetPost.likes;

    // Atualização otimista imediata para fluidez visual
    targetPost.youLiked = !wasLiked;
    targetPost.likes = wasLiked ? (previousLikes - 1) : (previousLikes + 1);
    notifyListeners();

    try {
      if (wasLiked) {
        await _api.unlikePost(postId);
      } else {
        await _api.likePost(postId);
      }
    } catch (e) {
      // Em caso de falha de rede, reverte o estado
      targetPost.youLiked = wasLiked;
      targetPost.likes = previousLikes;
      lastErrorMessage = e.toString();
      notifyListeners();
    }
  }

  // Verifica se o post está curtido pelo usuário
  bool isLiked(String postId) {
    for (final p in [...generalPosts, ...followingPosts]) {
      if (p.id == postId) return p.youLiked;
    }
    return false;
  }

  // ============================================================
  // SEÇÃO: USUÁRIOS & SEGUIDORES
  // ============================================================

  // ── Seguir / Deixar de seguir ─────────────────────────────────
  // Alterna seguir/deixar de seguir no back-end.
  Future<void> toggleFollow(String targetLogin) async {
    if (currentUser == null) return;

    final cachedUser = _userCache[targetLogin];
    final wasFollowing = cachedUser?.youFollow ?? false;

    // Atualização local imediata
    if (cachedUser != null) {
      cachedUser.youFollow = !wasFollowing;
      if (wasFollowing) {
        if (cachedUser.followers > 0) cachedUser.followers--;
        if (currentUser!.following > 0) currentUser!.following--;
      } else {
        cachedUser.followers++;
        currentUser!.following++;
      }
      notifyListeners();
    }

    try {
      if (wasFollowing) {
        await _api.unfollowUser(targetLogin);
      } else {
        await _api.followUser(targetLogin);
      }

      // Atualiza o perfil alvo e feeds
      await fetchUserProfile(targetLogin);
      await fetchFollowingPosts();
    } catch (e) {
      // Reverte em caso de erro
      if (cachedUser != null) {
        cachedUser.youFollow = wasFollowing;
      }
      lastErrorMessage = e.toString();
      notifyListeners();
    }
  }

  // Verifica se o usuário logado segue determinado login
  bool isFollowing(String userLogin) {
    if (_userCache.containsKey(userLogin)) {
      return _userCache[userLogin]!.youFollow;
    }
    return false;
  }

  // ── Buscar perfil detalhado de um usuário (GET /users/{login}) ──
  Future<User?> fetchUserProfile(String login) async {
    try {
      final data = await _api.getUser(login);
      final user = User.fromJson(data);
      _userCache[user.login] = user;
      if (login == currentUser?.login || login == 'me') {
        currentUser = user;
      }
      notifyListeners();
      return user;
    } catch (e) {
      lastErrorMessage = e.toString();
      return _userCache[login];
    }
  }

  // ── Buscar posts de um usuário específico (GET /users/{login}/posts) ─
  Future<List<Post>> fetchUserPosts(String login) async {
    try {
      final data = await _api.getUserPosts(login);
      return data.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      lastErrorMessage = e.toString();
      return [];
    }
  }

  // ── Buscar respostas a um post (GET /posts/{id}/replies) ─────────
  Future<List<Post>> fetchPostReplies(String postId) async {
    try {
      final data = await _api.getPostReplies(postId);
      return data.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      lastErrorMessage = e.toString();
      return [];
    }
  }

  // ── Busca de usuários (GET /users?search=) ────────────────────
  Future<List<User>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final data = await _api.searchUsers(search: query);
      final users = data.map((item) {
        final u = User.fromJson(item as Map<String, dynamic>);
        _userCache[u.login] = u;
        return u;
      }).toList();
      return users;
    } catch (e) {
      lastErrorMessage = e.toString();
      return [];
    }
  }

  // ── Busca de posts (GET /posts?search=) ───────────────────────
  Future<List<Post>> searchPosts(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final data = await _api.getPosts(search: query);
      return data.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      lastErrorMessage = e.toString();
      return [];
    }
  }

  // ── Editar perfil (PATCH /users/1) ────────────────────────────
  // Converte imagem para Base64 e atualiza dados no back-end.
  Future<bool> updateProfile(String name, String password, String? imagePath, {String? base64Image}) async {
    if (currentUser == null) return false;

    lastErrorMessage = null;
    try {
      if (base64Image == null && imagePath != null && imagePath.isNotEmpty && !imagePath.startsWith('http') && !imagePath.startsWith('blob:')) {
        final bytes = await File(imagePath).readAsBytes();
        base64Image = base64Encode(bytes);
      }

      await _api.updateUser(
        name: name.isNotEmpty ? name : null,
        password: password.isNotEmpty ? password : null,
        passwordConfirmation: password.isNotEmpty ? password : null,
        imageDataBase64: base64Image,
      );

      // Atualiza usuário atual
      if (name.isNotEmpty) currentUser!.name = name;
      if (password.isNotEmpty) currentUser!.password = password;

      // Se a senha mudou, renova a sessão para manter o app autenticado
      if (password.isNotEmpty) {
        try {
          await _api.login(currentUser!.login, password);
        } catch (_) {}
      }

      // Atualiza dados com o perfil mais recente da API
      await fetchUserProfile(currentUser!.login);

      notifyListeners();
      return true;
    } catch (e) {
      lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Excluir conta (DELETE /users/me) ──────────────────────────
  // Apaga a conta permanentemente no back-end.
  Future<bool> deleteProfile() async {
    if (currentUser == null) return false;

    try {
      await _api.deleteAccount();
      currentUser = null;
      generalPosts.clear();
      followingPosts.clear();
      _userCache.clear();
      notifyListeners();
      return true;
    } catch (e) {
      lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // SEÇÃO: GETTERS E MÉTODOS DE COMPATIBILIDADE COM A PARTE 1
  // ============================================================

  // ── Feed Geral ────────────────────────────────────────────────
  List<Post> get generalFeedPosts => generalPosts;

  // ── Feed "Seguindo" ───────────────────────────────────────────
  List<Post> get followingFeedPosts => followingPosts;

  // ── Posts (Lista completa combinada) ──────────────────────────
  List<Post> get posts => generalPosts;

  // ── Usuários (Lista de usuários conhecidos/cacheados) ──────────
  List<User> get users => _userCache.values.toList();

  // ── Posts por usuário ─────────────────────────────────────────
  List<Post> getPostsByUser(String userId) {
    return generalPosts.where((p) => p.userId == userId).toList();
  }

  // ── Buscar post por ID ────────────────────────────────────────
  Post? getPostById(String id) {
    try {
      return [...generalPosts, ...followingPosts].firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // ── Buscar usuário por ID/Login síncrono ───────────────────────
  User getUserById(String login) {
    if (currentUser != null && (currentUser!.login == login || currentUser!.id == login)) {
      return currentUser!;
    }
    if (_userCache.containsKey(login)) {
      return _userCache[login]!;
    }
    // Fallback gracioso com avatar dinâmico caso ainda não esteja no cache
    final fallbackUser = User(
      login: login,
      name: login,
      profileImage: 'https://ui-avatars.com/api/?name=${login.replaceAll(' ', '+')}&background=random&format=png',
    );
    _userCache[login] = fallbackUser;
    return fallbackUser;
  }
}