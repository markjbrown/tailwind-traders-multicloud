package Tailwind.Traders.Stock.Api.models;

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;

import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBAttribute;
import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBAutoGeneratedKey;
import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBHashKey;
import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBTable;

@Entity
@DynamoDBTable(tableName = "StockCollection")
public class StockItem {
    @Id
    @GeneratedValue(strategy= GenerationType.AUTO)
    @DynamoDBHashKey
	@DynamoDBAutoGeneratedKey
    private String id;
    @DynamoDBAttribute
    private Integer productId;
    @DynamoDBAttribute
	private Integer stockCount;
    @DynamoDBAttribute
    private String partition;

    public String getId() {
        return this.id;
    }
    public void setId(String id) {
        this.id = id;
    }

    public String getPartition() {
        return this.partition;
    }
    public void setPartition(String partition) {
        this.partition = partition;
    }

    public Integer getProductId() {
        return this.productId;
    }
    public void setProductId(Integer pid) {
        this.productId = pid;
    }

    public Integer getStockCount() {return this.stockCount; }
    public void setStockCount(Integer sc) { this.stockCount = sc; }
}
