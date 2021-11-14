// Install Deno. See https://deno.land/
// Run by `deno run --allow-net https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/rfqa-cloud-server/init_server.ts`

interface User {
  id?: string;
  username: string;
  email: string;
  password: string;
  first_name?: string;
  last_name?: string;
}

interface Team {
  id?: string;
  name: string;
  display_name: string;
  type: string;
  allow_open_invite: boolean;
}

type Cookie = string | null | undefined;

console.log("--------------------------");
const localServer = "http://localhost:8065";
console.log(`Server: ${localServer}`);
await createInitialUsersAndTeams(localServer);

// ***************************************
// Main function to create users and teams
// ***************************************
async function createInitialUsersAndTeams(server: string) {
  // Update as needed
  const firstUserAsAdmin: User = {
    email: "lindy@mattermost.com",
    username: "lindy",
    password: "Isherwood65#",
  };

  // Update as needed
  const adminUsers: User[] = [
    {
      email: "lindy+rainforest-admin@mattermost.com",
      username: "rainforest-admin",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "Admin",
    },
    {
      email: "lindy+sysadmin@mattermost.com",
      username: "sysadmin",
      password: "Sys@dmin-sample1",
      first_name: "Rainforest",
      last_name: "Sysadmin",
    },
  ];

  // Update as needed
  const regularUsers: User[] = [
    {
      email: "lindy+rainforest1@mattermost.com",
      username: "rainforest-1",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "One",
    },
    {
      email: "lindy+rainforest2@mattermost.com",
      username: "rainforest-2",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "Two",
    },
    {
      email: "lindy+rainforest3@mattermost.com",
      username: "rainforest-3",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "Three",
    },
    {
      email: "lindy+rainforest4@mattermost.com",
      username: "rainforest-4",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "Four",
    },
    {
      email: "lindy+rainforest5@mattermost.com",
      username: "rainforest-5",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "Five",
    },
    {
      email: "lindy+rainforest6@mattermost.com",
      username: "rainforest-6",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "Six",
    },
    {
      email: "lindy+rainforest-test@mattermost.com",
      username: "rainforest-test",
      password: "Rainforest1#",
      first_name: "Rainforest",
      last_name: "Test",
    },
  ];

  // Update as needed
  const teams: Team[] = [
    {
      name: "team-open",
      display_name: "Team Open",
      type: "O",
      allow_open_invite: true,
    },
    {
      name: "rainforest",
      display_name: "Rainforest",
      type: "O",
      allow_open_invite: true,
    },
  ];

  // Get image for user profile
  const profileImageUrl =
    "https://raw.githubusercontent.com/mattermost/mattermost-webapp/master/e2e/cypress/fixtures/mattermost-icon.png";
  const res = await fetch(profileImageUrl);
  const profileImageData = await res.blob();

  const createdUsers: Record<string, User> = {};
  const createdTeams: Record<string, Team> = {};

  // Create the first user and as the default admin
  const admin = await createNewUser(server, firstUserAsAdmin);
  console.log(`* @${admin.username} first user/admin created`);

  // Login as default admin
  // Do first visit to remove red dot in marketplace
  // Upload admin's profile image
  const { cookie } = await loginUser(server, firstUserAsAdmin);
  await firstAdminVisit(server, cookie);
  await uploadUserProfileImage(server, admin.id, profileImageData, cookie);

  // Create other admins
  const newAdminUsers = await Promise.all(
    adminUsers.map((user) =>
      createNewAdmin(server, user, profileImageData, cookie)
    ),
  );
  newAdminUsers.sort(byName).forEach((user) => {
    console.log(`** @${user.username} admin created`);
    createdUsers[user.id] = user;
  });

  // Create regular users
  const newRegularUsers = await Promise.all(
    regularUsers.map((user) =>
      createNewUser(server, user, profileImageData, cookie)
    ),
  );
  newRegularUsers.sort(byName).forEach((user) => {
    console.log(`*** @${user.username} user created`);
    createdUsers[user.id] = user;
  });

  // Create teams
  const newTeams = await Promise.all(
    teams.map((team) => createTeam(server, team, cookie)),
  );
  newTeams.sort(byName).forEach((team) => {
    console.log(`**** "${team.name}" team created`);
    createdTeams[team.id] = team;
  });

  newTeams.forEach(async (team) => {
    const newUsers = [...newAdminUsers, ...newRegularUsers];
    // Add users to teams
    const added = await Promise.all(
      newUsers.map((user) => addUserToTeam(server, team.id, user.id, cookie)),
    );

    added.map((ut) => {
      return {
        name: `***** @${createdUsers[ut.user_id].username} added to "${
          createdTeams[ut.team_id].name
        }" team`,
      };
    }).forEach((ut) => {
      console.log(ut.name);
    });

    // Promote users as team admins
    await Promise.all(
      newUsers.map((user) =>
        promoteUserAsTeamAdmin(server, team.id, user.id, cookie)
      ),
    );
    console.log(
      `${
        newUsers.map((u) => `@${u.username}`).join(",")
      } promoted as "${team.name}" team admin`,
    );
  });
}

async function createNewAdmin(
  baseUrl: string,
  user: Partial<User>,
  profileImageData: Blob,
  cookie: Cookie,
) {
  const newAdmin = await createNewUser(baseUrl, user, profileImageData, cookie);
  await patchUserRole(baseUrl, newAdmin.id, "system_admin system_user", cookie);

  return newAdmin;
}

async function createNewUser(
  baseUrl: string,
  user: Partial<User>,
  profileImageData?: Blob,
  cookie?: Cookie,
) {
  const newUser = await createUser(baseUrl, user, cookie);

  if (cookie) {
    await updateUserPreference(baseUrl, newUser.id, cookie);
  }

  if (cookie && profileImageData) {
    await uploadUserProfileImage(baseUrl, newUser.id, profileImageData, cookie);
  }

  return newUser;
}

// ******************
// API call to server
// ******************

async function loginUser(baseUrl: string, user: Partial<User>) {
  const headers = getHeaders();
  const response = await fetch(`${baseUrl}/api/v4/users/login`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      login_id: user.username || user.email,
      password: user.password,
    }),
  });

  if (!response.ok) {
    await throwError(response, `Failed to login as @${user.username}`);
  }

  const data = await response.json();

  return { user: data, cookie: response.headers.get("set-cookie") };
}

async function firstAdminVisit(
  baseUrl: string,
  cookie?: Cookie,
) {
  const headers = getHeaders(cookie);
  const response = await fetch(
    `${baseUrl}/api/v4/plugins/marketplace/first_admin_visit`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({ first_admin_visit_marketplace_status: true }),
    },
  );

  if (!response.ok) {
    await throwError(response, "Failed to remove red dot on marketplace");
  }

  console.log(`* first admin visit done (removed marketplace red dot)`);

  return response.json();
}

async function createUser(
  baseUrl: string,
  user: Partial<User>,
  cookie: Cookie,
) {
  const headers = getHeaders(cookie);
  const response = await fetch(`${baseUrl}/api/v4/users`, {
    method: "POST",
    headers,
    body: JSON.stringify(user),
  });

  if (!response.ok) {
    await throwError(response, `Failed to create @${user.username} user`);
  }

  return response.json();
}

async function patchUserRole(
  baseUrl: string,
  userId: string,
  roles: string,
  cookie: Cookie,
) {
  const headers = getHeaders(cookie);
  const response = await fetch(`${baseUrl}/api/v4/users/${userId}/roles`, {
    method: "PUT",
    headers,
    body: JSON.stringify({ roles }),
  });

  if (!response.ok) {
    await throwError(response, `Failed to update user role to "${roles}"`);
  }

  return response.json();
}

async function updateUserPreference(
  baseUrl: string,
  userId: string,
  cookie: Cookie,
) {
  const preferences = [
    {
      user_id: userId,
      category: "tutorial_step",
      name: userId,
      value: "999",
    },
  ];
  const headers = getHeaders(cookie);
  const response = await fetch(
    `${baseUrl}/api/v4/users/${userId}/preferences`,
    {
      method: "PUT",
      headers,
      body: JSON.stringify(preferences),
    },
  );

  if (!response.ok) {
    await throwError(
      response,
      "Failed to update user preferences",
    );
  }

  return response.json();
}

async function uploadUserProfileImage(
  baseUrl: string,
  userId: string,
  imageData: Blob,
  cookie: Cookie,
) {
  const headers = getHeaders(cookie);
  const formData = new FormData();
  formData.append("image", imageData);

  const response = await fetch(
    `${baseUrl}/api/v4/users/${userId}/image`,
    {
      method: "POST",
      headers,
      body: formData,
    },
  );

  if (!response.ok) {
    await throwError(
      response,
      "Failed to upload profile image",
    );
  }

  return response.json();
}

async function createTeam(baseUrl: string, team: Team, cookie: Cookie) {
  const headers = getHeaders(cookie);
  const response = await fetch(`${baseUrl}/api/v4/teams`, {
    method: "POST",
    headers,
    body: JSON.stringify(team),
  });

  if (!response.ok) {
    await throwError(response, `Failed to create "${team.name}" team`);
  }

  return response.json();
}

async function addUserToTeam(
  baseUrl: string,
  teamId: string,
  userId: string,
  cookie: Cookie,
) {
  const headers = getHeaders(cookie);
  const response = await fetch(`${baseUrl}/api/v4/teams/${teamId}/members`, {
    method: "POST",
    headers,
    body: JSON.stringify({ team_id: teamId, user_id: userId }),
  });

  if (!response.ok) {
    await throwError(response, "Failed to add user to team");
  }

  return response.json();
}

async function promoteUserAsTeamAdmin(
  baseUrl: string,
  teamId: string,
  userId: string,
  cookie: Cookie,
) {
  const headers = getHeaders(cookie);
  const response = await fetch(
    `${baseUrl}/api/v4/teams/${teamId}/members/${userId}/schemeRoles`,
    {
      method: "PUT",
      headers,
      body: JSON.stringify({
        scheme_user: true,
        scheme_admin: true,
      }),
    },
  );

  if (!response.ok) {
    await throwError(response, "Failed to promote user to team");
  }

  return response.json();
}

// ******************
// Utility functions
// ******************

function getHeaders(cookie?: Cookie): Headers {
  const headers = new Headers();
  headers.append("X-Requested-With", "XMLHttpRequest");
  if (cookie) {
    headers.append("Cookie", cookie);
  }

  return headers;
}

async function throwError(response: Response, message: string) {
  const err = await response.json();
  console.log(err);

  // Intentionally throw an error to make sure server state is as expected
  // before continuing to actual test.
  throw new Error(
    `${message}. Need to reset the server again and repeat running the script.`,
  );
}

function byName<T extends User & Team>(a: T, b: T): number {
  if (a.username) {
    return a.username.localeCompare(b.username);
  }

  return a.name.localeCompare(b.name);
}
