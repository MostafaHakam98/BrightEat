class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String role;
  final String? instapayLink;
  final String? instapayQrCode;
  final String? instapayQrCodeUrl;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    required this.role,
    this.instapayLink,
    this.instapayQrCode,
    this.instapayQrCodeUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      role: json['role'] ?? 'user',
      instapayLink: json['instapay_link'],
      instapayQrCode: json['instapay_qr_code'],
      instapayQrCodeUrl: json['instapay_qr_code_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'instapay_link': instapayLink,
      'instapay_qr_code': instapayQrCode,
    };
  }
}

