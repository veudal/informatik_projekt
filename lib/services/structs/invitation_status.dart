enum InvitationStatus {
  redeemable,
  pending,
  accepted,
  denied,
  expired,
  invalidated;

  static InvitationStatus? fromString(String s) {
    switch (s) {
      case 'REDEEMABLE':
        return redeemable;
      case 'PENDING':
        return pending;
      case 'ACCEPTED':
        return accepted;
      case 'DENIED':
        return denied;
      case 'EXPIRED':
        return expired;
      case 'INVALIDATED':
        return invalidated;
    }

    return null;
  }
}
