# Course Payment Escrow Smart Contract

## Description

The **Course Payment Escrow** is a Clarity smart contract built for the Stacks blockchain. It enables secure, milestone-based payments between students and course providers. Funds are held in escrow until agreed conditions are met—such as course completion, delivery confirmation, or instructor performance—ensuring fairness for both parties.

## Features

- 🧾 **Secure Payments:** Students deposit STX into escrow before course delivery.
- 🎓 **Instructor Payouts:** Funds are released to the instructor upon successful completion or milestone approval.
- 🔁 **Refund Option:** Students can receive refunds if the course is not completed or the time limit expires.
- ⏱️ **Timeout Logic:** Escrow can auto-refund after a predefined period without instructor claims.
- 🛠️ **Dispute Handling (Optional):** Add a mediator role for manual dispute resolution.

## Core Functions

- `deposit`: Student deposits STX for a course.
- `release`: Instructor claims payment after course delivery.
- `refund`: Student reclaims funds if course isn’t completed within the time limit.
- `get-escrow-status`: View the current status of a course escrow agreement.
- `admin-resolve` *(optional)*: Admin resolves disputes and releases/refunds funds accordingly.

## Setup & Testing

Built using [Clarinet](https://docs.stacks.co/docs/clarity/clarinet/overview/), the development toolchain for Clarity smart contracts.

### Run Tests

```bash
clarinet test
