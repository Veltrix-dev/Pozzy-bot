abstract final class UserRoles {
  static const user = 'user';
  static const admin = 'admin';

  static bool isAdminRole(String? value) => value == admin;

  static String normalize(String? value) {
    return isAdminRole(value) ? admin : user;
  }
}