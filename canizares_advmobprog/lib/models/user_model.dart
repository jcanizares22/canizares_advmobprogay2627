enum LoginType { firebase, dummyJson }

class UserModel {
  const UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.contactNumber,
    required this.username,
    required this.email,
    this.loginType = LoginType.firebase,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final int age;
  final String contactNumber;
  final String username;
  final String email;
  final LoginType loginType;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: (map['uid'] ?? map['id'] ?? '').toString(),
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
        contactNumber:
          (map['contactNumber'] ?? map['contactNo'] ?? map['phone'] ?? '')
            .toString(),
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
        loginType: map['loginType'] == LoginType.dummyJson.name
          ? LoginType.dummyJson
          : LoginType.firebase,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'firstName': firstName,
    'lastName': lastName,
    'age': age,
    'contactNumber': contactNumber,
    'username': username,
    'email': email,
    'loginType': loginType.name,
  };

  UserModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    int? age,
    String? contactNumber,
    String? username,
    String? email,
    LoginType? loginType,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      age: age ?? this.age,
      contactNumber: contactNumber ?? this.contactNumber,
      username: username ?? this.username,
      email: email ?? this.email,
      loginType: loginType ?? this.loginType,
    );
  }
}
