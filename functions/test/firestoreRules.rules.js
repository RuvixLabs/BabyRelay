"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-babyrelay",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "..", "firestore.rules"),
        "utf8",
      ),
    },
  });
});

test.after(async () => {
  await environment.cleanup();
});

function freeFamily(ownerId) {
  return {
    ownerId,
    memberIds: [ownerId],
    inviteCode: "ABC234",
    familySubscriptionActive: false,
    familySubscriptionPlanId: "",
    familySubscriptionOwnerId: "",
    updatedBy: ownerId,
  };
}

test("client-created families must start on the free entitlement", async () => {
  const owner = environment.authenticatedContext("owner").firestore();
  await assertSucceeds(
    owner.doc("families/free-family").set(freeFamily("owner")),
  );
  await assertFails(
    owner.doc("families/forged-family").set({
      ...freeFamily("owner"),
      familySubscriptionActive: true,
      familySubscriptionPlanId: "babyrelay_pro_annual",
      familySubscriptionOwnerId: "owner",
    }),
  );
});

test("even a family owner cannot promote client subscription fields", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("families/existing-family")
      .set(freeFamily("owner"));
  });
  const owner = environment.authenticatedContext("owner").firestore();

  await assertSucceeds(owner.doc("families/existing-family").update({
    selectedChildId: "child-1",
    updatedBy: "owner",
  }));
  await assertFails(owner.doc("families/existing-family").update({
    familySubscriptionActive: true,
    familySubscriptionPlanId: "babyrelay_pro_monthly",
    familySubscriptionOwnerId: "owner",
  }));
});

test("trusted Admin writes can update the derived family entitlement", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const ref = context.firestore().doc("families/admin-family");
    await ref.set(freeFamily("owner"));
    await ref.update({
      familySubscriptionActive: true,
      familySubscriptionPlanId: "babyrelay_pro_special_annual",
      familySubscriptionOwnerId: "owner",
    });
    const snapshot = await ref.get();
    if (snapshot.data().familySubscriptionActive !== true) {
      throw new Error("Admin entitlement write did not persist");
    }
  });
});
