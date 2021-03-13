var textWrapper = document.querySelector('.ml12');
var mediums = textWrapper.querySelectorAll('.nav-link-hide');

var animationEnter;
var animationLeave;
if(document.getElementById('navBar')){
    document.getElementById('navBar').addEventListener("mouseenter", (event) => {
        if( window.innerWidth >= 1200 ){
                if (animationLeave){
            animationLeave.remove(textWrapper.querySelectorAll('.ml12 .letter'));
            }
            anime.set(mediums, {display : "block"});
            anime.set(textWrapper.querySelectorAll('.ml12 .letter'),{ translateX: 0});
            animationEnter = anime.timeline({loop: false})
            .add({
                targets: '.nav-link-hide',
                translateX: [5,0],
                opacity: [0,1],
                translateZ: 0,
                easing: "easeOutExpo",
                duration: 1200,
                delay: anime.stagger(100, {direction: 'reverse'}) // increase delay by 100ms for each elements.
              });
        }
    });

    document.getElementById('navBar').addEventListener("mouseleave", (event) => {
        if( window.innerWidth >= 1200 ){
            if (animationEnter){
                animationEnter.remove(textWrapper.querySelectorAll('.ml12 .letter'));
            }
            animationLeave = anime.timeline({loop: false})
                .add({
                    targets: '.ml12 .letter',
                    translateX: [0,-30],
                    opacity: [1,0],
                    easing: "easeInExpo",
                    duration: 1100,
                    delay: (el, i) => 100 + 30 * i
                })
            animationLeave.finished.then(function(){
                anime.set(mediums, {display : "none"});
                anime.timeline({loop: false}).add({
                        targets: '.nav-link-show',
                        translateX: [5,0],
                        opacity: [0,1],
                        translateZ: 0,
                        easing: "easeOutExpo",
                        duration: 1200,
                        delay: anime.stagger(100, {direction: 'reverse'}) // increase delay by 100ms for each elements.
                });
            });
        }
    });
}