import { gql } from "@apollo/client";

export const GET_VAULT_OVERVIEW = gql`
  query GetVaultOverview($vault: ID!) {
    vault(id: $vault) {
      id
      asset
      name
      symbol
      totalAssets
      totalShares
      performanceFeeBps
      createdAt
      txCount
    }
  }
`;

export const GET_USER_POSITIONS = gql`
  query GetUserPositions($user: ID!) {
    user(id: $user) {
      id
      totalDeposited
      totalWithdrawn
      deposits(orderBy: timestamp, orderDirection: desc, first: 10) {
        id
        assets
        shares
        timestamp
        txHash
      }
      withdraws(orderBy: timestamp, orderDirection: desc, first: 10) {
        id
        assets
        shares
        timestamp
        txHash
      }
    }
  }
`;

export const GET_VAULT_DAILY_SNAPSHOTS = gql`
  query GetVaultDailySnapshots($vault: ID!, $first: Int!) {
    vaultDailySnapshots(
      where: { vault: $vault }
      orderBy: timestamp
      orderDirection: desc
      first: $first
    ) {
      id
      totalAssets
      totalShares
      apy
      timestamp
    }
  }
`;

export const GET_ALL_VAULTS = gql`
  query GetAllVaults {
    vaults(orderBy: createdAt, orderDirection: desc) {
      id
      asset
      name
      symbol
      totalAssets
      totalShares
      performanceFeeBps
      createdAt
      txCount
    }
  }
`;
