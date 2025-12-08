import { ApolloClient, InMemoryCache, HttpLink } from "@apollo/client";

const SUBGRAPH_URL =
  process.env.NEXT_PUBLIC_SUBGRAPH_URL ??
  "https://api.studio.thegraph.com/query/placeholder/ferros-vault/v0.0.1";

export const apolloClient = new ApolloClient({
  link: new HttpLink({ uri: SUBGRAPH_URL }),
  cache: new InMemoryCache(),
  defaultOptions: {
    watchQuery: { fetchPolicy: "cache-and-network" },
  },
});
