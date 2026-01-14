/**
 * Super Xtreme Mapping - Product Website
 * Main JavaScript
 */

(function() {
    'use strict';

    // --------------------------------------------------------------------------
    // Scroll Reveal Animation
    // --------------------------------------------------------------------------
    const sections = document.querySelectorAll('.section');

    const revealSection = (entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                // Once revealed, no need to observe anymore
                observer.unobserve(entry.target);
            }
        });
    };

    const sectionObserver = new IntersectionObserver(revealSection, {
        root: null,
        threshold: 0.15,
        rootMargin: '0px'
    });

    sections.forEach(section => {
        sectionObserver.observe(section);
    });

    // --------------------------------------------------------------------------
    // Navigation Scroll Effect
    // --------------------------------------------------------------------------
    const nav = document.querySelector('.nav');
    let lastScrollY = window.scrollY;
    let ticking = false;

    const updateNav = () => {
        const scrollY = window.scrollY;

        if (scrollY > 100) {
            nav.style.background = 'rgba(12, 10, 9, 0.95)';
        } else {
            nav.style.background = 'linear-gradient(to bottom, rgba(12, 10, 9, 1), transparent)';
        }

        ticking = false;
    };

    window.addEventListener('scroll', () => {
        lastScrollY = window.scrollY;
        if (!ticking) {
            window.requestAnimationFrame(updateNav);
            ticking = true;
        }
    });

    // --------------------------------------------------------------------------
    // Smooth Scroll for Anchor Links
    // --------------------------------------------------------------------------
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const href = this.getAttribute('href');
            if (href === '#') return;

            const target = document.querySelector(href);
            if (target) {
                e.preventDefault();
                const headerOffset = 80;
                const elementPosition = target.getBoundingClientRect().top;
                const offsetPosition = elementPosition + window.scrollY - headerOffset;

                window.scrollTo({
                    top: offsetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });

    // --------------------------------------------------------------------------
    // App Preview Animation (subtle movement on scroll)
    // --------------------------------------------------------------------------
    const appPreview = document.querySelector('.app-preview');

    if (appPreview) {
        window.addEventListener('scroll', () => {
            const rect = appPreview.getBoundingClientRect();
            const windowHeight = window.innerHeight;

            if (rect.top < windowHeight && rect.bottom > 0) {
                const progress = (windowHeight - rect.top) / (windowHeight + rect.height);
                const rotation = (progress - 0.5) * 2;
                appPreview.style.transform = `perspective(1000px) rotateY(${rotation}deg)`;
            }
        });
    }

    // --------------------------------------------------------------------------
    // Feature Cards Hover Effect (cursor tracking)
    // --------------------------------------------------------------------------
    const featureCards = document.querySelectorAll('.feature-card');

    featureCards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;

            card.style.setProperty('--mouse-x', `${x}px`);
            card.style.setProperty('--mouse-y', `${y}px`);
        });
    });

    // --------------------------------------------------------------------------
    // Console Easter Egg
    // --------------------------------------------------------------------------
    console.log('%c🎛️ Super Xtreme Mapping', 'font-size: 24px; font-weight: bold; color: #f59e0b;');
    console.log('%cThe TSI editor Traktor deserves.', 'font-size: 14px; color: #a8a29e;');
    console.log('%cBuilt with ❤️ for the DJ community', 'font-size: 12px; color: #78716c;');

})();
