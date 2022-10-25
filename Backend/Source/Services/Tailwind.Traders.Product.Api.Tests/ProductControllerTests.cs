using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;
using System.Collections.Generic;
using System.Threading.Tasks;
using Tailwind.Traders.Product.Api.Controllers;
using Tailwind.Traders.Product.Api.Models;
using Tailwind.Traders.Product.Api.Repos;

namespace Tailwind.Traders.Product.Api.Tests
{
    [TestClass]
    public class ProductControllerTests
    {
        [TestMethod]
        public async Task TestAllProductsAsync()
        {
            var appSettings = new AppSettings { ProductImagesUrl = "http://localhost:5000" };

            var options = Options.Create(appSettings);
            var mockProductItemRepository = new Mock<IProductItemRepository>();
            mockProductItemRepository.Setup(r => r.GetAllProductsAsync())
                .ReturnsAsync(new List<ProductItem>
                {
                    new ProductItem
                    {
                        Id = 123,
                        Name = "Name",
                        Price = 42.00f,
                        ImageName = "ImageName.jpg",
                        BrandId = 1,
                        Brand = new ProductBrand { Id = 1, Name = "Brand"},
                        TypeId = 23,
                        Type = new ProductType { Id = 23, Code = "home", Name = "White Door" },
                        TagId = 3,
                        Tag = new ProductTag { Id = 3, Value = "tag" },
                    }
                });
            var controller = new ProductController(
                mockProductItemRepository.Object,
                new NullLogger<ProductController>(),
                new Mappers.MapperDtos(options),
                options);

            var result = await controller.AllProductsAsync();
            var okResult = result as OkObjectResult;
            Assert.IsNotNull(okResult);
        }


    }
}
