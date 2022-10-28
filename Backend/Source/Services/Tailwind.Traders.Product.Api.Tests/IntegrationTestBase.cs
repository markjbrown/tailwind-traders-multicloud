﻿using System.Net.Http;

namespace Tailwind.Traders.Product.Api.Tests
{
    public class IntegrationTestBase
    {
        protected ApiHost ApiHost = new ApiHost();
        protected HttpClient ApiClient => ApiHost.Client;

        protected string ApiPath(string path) => ApiHost.Url(path);

        public IntegrationTestBase()
        {
        }

        protected void Initialize(string cloudPlatform)
        {
            ApiHost.Initialize(cloudPlatform);
        }
    }
}