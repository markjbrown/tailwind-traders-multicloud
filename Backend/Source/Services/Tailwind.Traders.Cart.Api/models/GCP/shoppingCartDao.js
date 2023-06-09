class ShoppingCartDao {
  constructor(serviceAccount, collectionId) {
    this.Firebaseclient = serviceAccount;
    this.collectionId = collectionId;
    this.dataRef = this.Firebaseclient.collection(collectionId);
  }

  async init() {}

  async find(email) {
    var result = [];
    const snapshot = await this.dataRef
      .where("detailProduct.email", "==", email)
      .get();

    if (snapshot.empty) {
      console.log("No matching documents.");
      return result;
    }

    snapshot.forEach((doc) => {
      let res = doc.data();
      result.push({
        id: res.detailProduct.id,
        name: res.detailProduct.name,
        price: res.detailProduct.price,
        imageUrl: res.detailProduct.imageUrl,
        email: res.detailProduct.email,
        qty: res.qty,
        _cdbid: doc.id,
      });
    });

    return result;
  }

  async addItem(item) {
    try {
      let docRef = await this.dataRef.add(item);
      if (docRef.id) {
        var doc = await this.dataRef.doc(docRef.id).get();
        let result = doc.data();
        result.id = doc.id;
        return result;
      } else {
        return { message: "Record not inserted" };
      }
    } catch (e) {
      throw new Error(`Firestore DB error ${e.message} `);
    }
  }

  async updateQuantity(id, newqty) {
    try {
      const res = await this.dataRef.doc(id).update({ qty: newqty });
    } catch (e) {
      throw new Error(
        `Firestore DB error ${e.message} when loading doc with id ${id}`
      );
    }
  }

  async deleteItem(id) {
    try {
      const res = await this.dataRef.doc(id).delete();
    } catch (e) {
      throw new Error(`Firestore DB ${e.code} when deleting doc with id ${id}`);
    }
  }
}

module.exports = ShoppingCartDao;
