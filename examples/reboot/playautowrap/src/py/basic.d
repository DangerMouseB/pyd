module py.basic;


export struct Visible {
    int id;
    this(int id) {
        this.id = id;
    }
}


struct NotInvisible {
    int id;
    this(int id) {
        this.id = id;
    }
}
