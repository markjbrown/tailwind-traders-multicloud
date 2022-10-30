﻿using CsvHelper.Configuration;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using Tailwind.Traders.Product.Api.AwsClients;
using Tailwind.Traders.Product.Api.HealthCheck;
using Tailwind.Traders.Product.Api.Infrastructure;
using Tailwind.Traders.Product.Api.Mappers;
using Tailwind.Traders.Product.Api.Repositories;

namespace Tailwind.Traders.Product.Api.Extensions
{
    public static class ServiceCollectionsExtensions
    {
        const string AZURE_CLOUD = "AZURE";
        const string AWS_CLOUD = "AWS";
        const string GCP_CLOUD = "GCP";
        public static IServiceCollection AddProductsContext(this IServiceCollection service, AzureCosmosDbConfig cosmosDbConfig)
        {
            service.AddDbContext<ProductContext>(options =>
            {
                options.UseCosmos(cosmosDbConfig.Host, cosmosDbConfig.Key, cosmosDbConfig.Database)
                    .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);
            });

            return service;
        }

        public static IServiceCollection AddModulesProducts(this IServiceCollection service, IConfiguration configuration)
        {
            service.AddTransient<IProcessFile, ProccessCsv>()
                .AddTransient<ClassMap, ProductBrandMap>()
                .AddTransient<ClassMap, ProductFeatureMap>()
                .AddTransient<ClassMap, ProductItemMap>()
                .AddTransient<ClassMap, ProductTypeMap>()
                .AddTransient<ClassMap, ProductTagMap>()
                .AddTransient<MapperDtos>();

            string env = configuration["CLOUD_PLATFORM"];

            var cosmosDbOptions = new AzureCosmosDbConfig();
            configuration.GetSection(AzureCosmosDbConfig.ConfigKey).Bind(cosmosDbOptions);

            if (env == AZURE_CLOUD)
            {
                service.AddTransient<ISeedDatabase, AzureProductDatabaseSeeder>();
                service.AddScoped<IProductItemRepository, AzureCosmosDbProductItemRepository>();
                service.AddProductsContext(cosmosDbOptions);
            }
            else if (env == AWS_CLOUD)
            {
                service.AddTransient<AmazonDynamoDbClientFactory>();
                service.AddTransient<ISeedDatabase, AwsProductDatabaseSeeder>();
                service.AddScoped<IProductItemRepository, AwsDynamoDbProductItemRepository>();
            }
            else if (env == GCP_CLOUD)
            {
                service.AddTransient<ISeedDatabase, GcpProductDatabaseSeeder>();
                service.AddScoped<IProductItemRepository, GcpFirestoreProductItemRepository>();
            }

            service.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();


            return service;
        }

        public static IServiceCollection AddHealthChecks(this IServiceCollection services, IConfiguration configuration)
        {
            var hcBuilder = services.AddHealthChecks();
            hcBuilder.AddCheck("self", () => HealthCheckResult.Healthy());
            return services;
        }
    }
}
