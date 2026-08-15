import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_gateway.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:pozzy_bot/utils/telegram_username.dart';

enum FragmentRecipientResolutionOutcome {
  resolved,
  invalidUsername,
  recipientNotFound,
  serviceUnavailable,
  unexpectedResponse,
}

class FragmentRecipientResolutionResult {
  const FragmentRecipientResolutionResult(this.outcome, {this.username});

  final FragmentRecipientResolutionOutcome outcome;
  final String? username;
}

class FragmentRecipientResolver {
  FragmentRecipientResolver(this._gateway);

  final FragmentGateway _gateway;

  Future<FragmentRecipientResolutionResult> resolve(String rawUsername) async {
    final username = TelegramUsername.normalize(rawUsername);
    if (username == null) {
      return const FragmentRecipientResolutionResult(
        FragmentRecipientResolutionOutcome.invalidUsername,
      );
    }

    try {
      final recipient = await _gateway.searchUser(username);
      final resolvedUsername = TelegramUsername.normalize(recipient.username);
      if (resolvedUsername == null || resolvedUsername != username) {
        BotLog.error(
          'fragment recipient_mismatch requested=$username '
          'returned_username_valid=${resolvedUsername != null}',
        );
        return const FragmentRecipientResolutionResult(
          FragmentRecipientResolutionOutcome.unexpectedResponse,
        );
      }
      return FragmentRecipientResolutionResult(
        FragmentRecipientResolutionOutcome.resolved,
        username: resolvedUsername,
      );
    } on FragmentApiException catch (error) {
      BotLog.error(
        'fragment recipient_lookup_failed username=$username '
        'kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
      );
      final recipientRejected =
          error.kind == FragmentApiErrorKind.rejected ||
          (error.kind == FragmentApiErrorKind.httpClient &&
              (error.statusCode == 400 || error.statusCode == 404));
      final outcome = recipientRejected
          ? FragmentRecipientResolutionOutcome.recipientNotFound
          : switch (error.kind) {
              FragmentApiErrorKind.malformedResponse =>
                FragmentRecipientResolutionOutcome.unexpectedResponse,
              _ => FragmentRecipientResolutionOutcome.serviceUnavailable,
            };
      return FragmentRecipientResolutionResult(outcome);
    } catch (error, stackTrace) {
      BotLog.error(
        'fragment recipient_lookup_unexpected username=$username '
        'error=$error\n$stackTrace',
      );
      return const FragmentRecipientResolutionResult(
        FragmentRecipientResolutionOutcome.serviceUnavailable,
      );
    }
  }
}
