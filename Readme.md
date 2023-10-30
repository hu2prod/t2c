# t2c code gnerator
Кодогенератор був зроблений для персонального використання \
Приклад "хочу backend, frontend, postgres, sequelize, meilisearch, прокинути DB на FE" \
Замість того, щоб шукати по всім моїм проектам де що я як зробив я просто мерджу конфігурації (дещо схоже на terraform та yeoman)

Використовує
* https://github.com/hu2prod/snpm
* https://github.com/hu2prod/story_book
* https://github.com/hu2prod/webcom

Приклади див в examples

Може містити помилки, що не дозволять працювати ні на якій машині окрім моєї

Never be production-ready

# install

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    source ~/.bashrc
    nvm i 16
    npm i -g iced-coffee-script pnpm
    
    git clone https://github.com/vird/t2c
    git clone https://github.com/vird/snpm
    git clone https://github.com/vird/story_book
    
    cd t2c
    pnpm i -g
    ./completion_install.sh
    cd ..
    
    # optional
    cd snpm
    pnpm i -g
    cd ..

# usage

    t2c init
    t2c build1
    t2c build1_watch
    # для більш складних речей
    t2c build2

# precatutions
* Див папку code_bubble
* Бажано напряму не змінювати файли, а через code_bubble або override (якщо вони працюють, якщо ні, то треба дописати)
* commit frequently, бо затерти корисні зміни дуже легко
