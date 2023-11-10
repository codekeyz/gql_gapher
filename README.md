# gql_codegen

Tired of writing your queries & mutation as raw strings `r""" """` in Dart and Flutter? 👋

Validate and generate typed request classes for all your queries and mutations defined in GraphQL `(.graphql|.gql)` files. It also supports Fragments.

## Usage

Add `gql_codegen` to your dev dependencies

```yaml
dev_dependencies:
  gql_codegen: any   // required dart >=2.12.0
  build_runner:
```

### Write your queries & mutations

```graphql
mutation AuthenticateUser(
  $first: String!
  $second: Int!
  $third: Boolean
  $fourth: Float
) {
  authenticate(
    input: {
      firebase: { token: $first }
      data: { attempt: $second }
      amount: $third
    }
    rememberMe: $fourth
  ) {
    user {
      id
      email
      phone
    }
  }
}
```

then run the generator

```sh
# dart
dart pub run build_runner build

# flutter
flutter pub run build_runner build
```

### Use it

```dart
import 'authenticate.g.dart';

void main() {
  final authPreq =
      AuthenticateUserRequest('some-token', 2, amount: 10, persist: true);

  print(authPreq.query); // query

  print(authPreq.variables); // variables

  print(authPreq.operation); // AuthenticateUser
}
```

## More

### Fragments Support

Fragment Imports are supported as seen in the sample below.

```graphql
#import "../fragments/user_fragment.graphql"

mutation GetUser($token: String!) {
  authenticate(input: { firebase: { token: $token } }, rememberMe: true) {
    __typename
    ...UserFragment
  }
}
```

## Contributors ✨

Contributions of any kind welcome!
