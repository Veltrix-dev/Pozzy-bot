# POZZY BOT

Dart Telegram bot with a separate Python MTProto service for Telegram Star
Gifts.

## Gift service

The bot currently shows a seven-item gift catalog. Product payment is not yet
connected, so choosing a gift displays a development notice and does not send
anything.

The Telegram entrypoint for a future payment callback is
`GiftPurchaseHandler.deliverPaidGift`. It first shows the processing status and
then calls `GiftPurchaseService`. It must be called only after an external
payment provider confirms a unique payment ID. A successful delivery is added
to user statistics and credits the existing referral commission.

Userbot setup and startup instructions are in `userbot/README.md`.
