import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/security/token_store.dart';
import '../domain/oauth_token.dart';
import 'pkce.dart';

/// Opens the browser and returns the callback URL that carries the code.
typedef AuthorizationLauncher = Future<String> Function(
  String url,
  String callbackUrlScheme,
);

/// Refreshes the access token of a session.
abstract class TokenRefresher {
  Future<OAuthToken> refresh(OAuthToken current);
}

/// Performs the OAuth2 PKCE flow against the Discord public client.
class AuthRepository implements TokenRefresher {
  AuthRepository({
    required this.config,
    required this.tokenStore,
    required this._dio,
    AuthorizationLauncher? launcher,
    this.discordApiBase = 'https://discord.com/api/v10',
    this.discordAuthorizeUrl = 'https://discord.com/oauth2/authorize',
  }) : _launcher = launcher ?? _defaultLauncher;

  final AppConfig config;
  final TokenStorage tokenStore;
  final Dio _dio;
  final AuthorizationLauncher _launcher;
  final String discordApiBase;
  final String discordAuthorizeUrl;

  static Future<String> _defaultLauncher(
    String url,
    String callbackUrlScheme,
  ) async {
    try {
      return await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
      );
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED' || error.code == 'CANCELLED') {
        throw const CancelledFailure('The sign in was cancelled.');
      }
      throw DiscordApiFailure(
        detail: error.message ?? 'The browser could not be opened.',
        statusCode: 0,
      );
    }
  }

  /// Builds the authorization URL for a fresh verifier and state.
  ({String verifier, String state, String url}) buildAuthorizationRequest() {
    final verifier = Pkce.createVerifier();
    final state = Pkce.createState();
    final challenge = Pkce.challengeFromVerifier(verifier);
    final uri = Uri.parse(discordAuthorizeUrl).replace(
      queryParameters: {
        'client_id': config.discordClientId,
        'response_type': 'code',
        'redirect_uri': config.redirectUri,
        'scope': 'identify guilds',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );
    return (verifier: verifier, state: state, url: uri.toString());
  }

  /// Runs the full sign in flow and stores the resulting tokens.
  Future<OAuthToken> signIn() async {
    final request = buildAuthorizationRequest();
    final callback = await _launcher(request.url, AppConfig.callbackScheme);
    final parameters = Uri.parse(callback).queryParameters;

    final error = parameters['error'];
    if (error != null) {
      if (error == 'access_denied') {
        throw const CancelledFailure('The sign in was cancelled.');
      }
      throw DiscordApiFailure(
        detail: _describeOAuthError(parameters),
        statusCode: 0,
      );
    }

    if (parameters['state'] != request.state) {
      throw const ValidationFailure(
        'The sign in response did not match the request and was rejected.',
      );
    }

    final code = parameters['code'];
    if (code == null || code.isEmpty) {
      throw const ValidationFailure(
        'Discord did not return an authorization code.',
      );
    }

    final token = await _exchange({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': config.redirectUri,
      'code_verifier': request.verifier,
    });

    await tokenStore.write(token);
    return token;
  }

  /// Exchanges a refresh token for a new access token.
  @override
  Future<OAuthToken> refresh(OAuthToken current) async {
    final token = await _exchange({
      'grant_type': 'refresh_token',
      'refresh_token': current.refreshToken,
    });
    await tokenStore.write(token);
    return token;
  }

  /// Revokes the refresh token. Failures are swallowed by the caller.
  Future<void> revoke(OAuthToken token) async {
    await _dio.post<Object?>(
      '$discordApiBase/oauth2/token/revoke',
      data: <String, Object?>{
        'client_id': config.discordClientId,
        'token': token.refreshToken,
      },
    );
  }

  /// Clears the stored tokens. Always succeeds so a failed revocation cannot
  /// keep the user signed in.
  Future<void> signOut() async {
    await tokenStore.clear();
  }

  Future<OAuthToken> _exchange(Map<String, String> payload) async {
    final Response<Object?> response;
    try {
      response = await _dio.post<Object?>(
        '$discordApiBase/oauth2/token',
        data: <String, Object?>{
          'client_id': config.discordClientId,
          ...payload,
        },
      );
    } on DioException catch (error) {
      throw _mapOAuthError(error);
    }

    final body = response.data;
    if (body is! Map) {
      throw const UnknownFailure(
        'Discord returned an unexpected token response.',
      );
    }
    final accessToken = body['access_token'];
    final refreshToken = body['refresh_token'];
    final expiresIn = body['expires_in'];
    if (accessToken is! String ||
        refreshToken is! String ||
        expiresIn is! int) {
      throw const UnknownFailure(
        'Discord returned an incomplete token response.',
      );
    }
    return OAuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  AppFailure _mapOAuthError(DioException error) {
    final response = error.response;
    final body = response?.data;
    if (body is Map) {
      final oauthError = body['error'];
      final description = body['error_description'];
      if (oauthError is String) {
        if (oauthError == 'invalid_grant') {
          return InvalidGrantFailure(
            description is String && description.isNotEmpty
                ? '$oauthError: $description'
                : oauthError,
          );
        }
        return DiscordApiFailure(
          detail: _describeOAuthError(body),
          statusCode: response?.statusCode ?? 0,
        );
      }
      if (description is String) {
        return DiscordApiFailure(
          detail: description,
          statusCode: response?.statusCode ?? 0,
        );
      }
    }
    return mapDioException(error);
  }

  String _describeOAuthError(Map<Object?, Object?> parameters) {
    final error = parameters['error'];
    final description = parameters['error_description'];
    if (error is String && description is String && description.isNotEmpty) {
      return '$error: $description';
    }
    if (error is String) {
      return error;
    }
    if (description is String) {
      return description;
    }
    return 'Discord rejected the request.';
  }
}
