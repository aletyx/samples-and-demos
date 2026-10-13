import 'package:faker/faker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mortgagehub_app/proposal/proposal_check.dart';
import 'package:mortgagehub_app/proposal/proposal_request.dart';
import 'package:mortgagehub_app/proposal/targeted_proposal.dart';

/// The form's own checks (proposal_form_screen.dart): a targeted request
/// must pass them, whatever verdict it aims for.
void expectFormValid(ProposalRequest r) {
  expect(r.propertyValue, greaterThan(0));
  expect(r.loanAmount, inExclusiveRange(0, r.propertyValue));
  if (!r.purpose.isPurchase) expect(r.currentBalance, greaterThan(0));
  if (r.purpose == LoanPurpose.cashOutRefinance) {
    expect(r.cashOut, greaterThan(0));
  }
  if (r.program case LoanProgram.fha || LoanProgram.va || LoanProgram.usda) {
    expect(r.occupancy, Occupancy.primary);
  }
  if (r.program == LoanProgram.va) expect(r.militaryService, isTrue);
  if (r.propertyFound) expect(r.street, isNotEmpty);
  expect(r.zip, matches(RegExp(r'^\d{5}$')));
  expect(r.annualIncome, greaterThan(0));
  expect(r.monthlyDebts, greaterThanOrEqualTo(0));
  if (!r.purpose.isPurchase) expect(r.firstTimeBuyer, isFalse);
}

void main() {
  for (final target in CheckStatus.values) {
    test('${target.label} requests pass the form\'s checks', () {
      final faker = Faker(seed: target.index);
      for (var i = 0; i < 300; i++) {
        expectFormValid(targetedProposal(target, faker));
      }
    });
  }

  test('processable requests stay clear of the limits', () {
    final faker = Faker(seed: 11);
    for (var i = 0; i < 300; i++) {
      final r = targetedProposal(CheckStatus.processable, faker);
      expect(r.creditScore, isNot(CreditScoreRange.unknown));
      expect(r.creditScore, isNot(CreditScoreRange.below620));
      expect(r.program, isNot(LoanProgram.usda));
      expect(r.loanAmount, lessThanOrEqualTo(832750));
      if (r.program == LoanProgram.fha) {
        expect(r.loanAmount, lessThanOrEqualTo(541287));
      }
      expect(r.loanToValue, lessThanOrEqualTo(95));
    }
  });
}
