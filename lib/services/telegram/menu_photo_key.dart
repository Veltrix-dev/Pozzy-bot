enum MenuPhotoKey {
  mainMenu('main_menu.png', 'MENU_PHOTO_MAIN_MENU_FILE_ID'),
  buyStars('buy_stars_menu.png', 'MENU_PHOTO_BUY_STARS_FILE_ID'),
  buyPremium('buy_premium_menu.jpg', 'MENU_PHOTO_BUY_PREMIUM_FILE_ID'),
  buyTon('buy_ton_menu.jpg', 'MENU_PHOTO_BUY_TON_FILE_ID'),
  promocod('promokod_menu.png', 'MENU_PHOTO_PROMOKOD_FILE_ID'),
  buyDeleteGift('buy_delete_gift.png', 'MENU_PHOTO_BUY_DELETE_GIFT_FILE_ID'),
  newsProject('news_project_menu.png', 'MENU_PHOTO_NEWS_PROJECT_FILE_ID'),
  chatProject('chat_project_menu.png', 'MENU_PHOTO_CHAT_PROJECT_FILE_ID'),
  support('support.png', 'MENU_PHOTO_SUPPORT_FILE_ID'),
  checks('checks.png', 'MENU_PHOTO_CHECKS_FILE_ID'),
  adminMenu(
    'adminmenu.png',
    'MENU_PHOTO_ADMIN_MENU_FILE_ID',
    alternateFileNames: ['admin_menu.png'],
  );

  const MenuPhotoKey(
  this.fileName,
  this.envKey, {
    this.alternateFileNames = const [],
  });

  final String fileName;
  final String envKey;
  final List<String> alternateFileNames;

  List<String> get allFileNames => [fileName, ...alternateFileNames];

  String get sourceEnvKey => envKey.replaceAll('_FILE_ID', '_SOURCE');
}