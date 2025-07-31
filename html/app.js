// NUI Script (Vue.js 2)
new Vue({
    el: '#app',
    data: {
        visible: false,
        currentTab: 'startseite',
        tabs: ['startseite', 'meinCode', 'eingeladenePersonen', 'meineBelohnungen'],
        tabTranslations: {
            startseite: 'Startseite',
            meinCode: 'Mein Code',
            eingeladenePersonen: 'Geworbene Spieler',
            meineBelohnungen: 'Belohnungen'
        },
        myCode: '',
        enteredCode: '',
        invitedPlayers: [],
        rewards: [],
        unlockedRewardIds: [],
        message: { text: '', type: '' },
        copyMessage: '',
        isLoading: false,
        isSubmitting: false,
        hasReferredSomeone: false,
    },
    methods: {
        async postNuiMessage(eventName, data = {}) {
            const resourceName = 'ns_code'; // Name deines Ressourcenordners

            try {
                const resp = await fetch(`https://${resourceName}/${eventName}`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify(data),
                });
                if (!resp.ok) {
                    let errorText = `HTTP error! status: ${resp.status} (${resp.statusText}) for URL: ${resp.url}`;
                    try {
                        const errorData = await resp.json();
                        errorText = (errorData && errorData.message) ? `${errorText} - Server Message: ${errorData.message}` : errorText;
                    } catch (e) { /* Ignore if response body is not json */ }
                    throw new Error(errorText);
                }
                if (resp.headers.get("content-type") && resp.headers.get("content-type").includes("application/json")) {
                    return await resp.json();
                } else {
                    return { status: 'ok_non_json' };
                }
            } catch (error) {
                this.message = { text: `Kommunikationsfehler mit dem Server.`, type: 'error' };
                this.isLoading = false;
                throw error;
            }
        },

        handleNuiMessages(event) {
            const { action, ...data } = event.data;

            switch (action) {
                case 'setVisible':
                    this.visible = data.visible;
                    if (this.visible) {
                        this.isLoading = true;
                    } else {
                        this.resetMessages();
                        this.isLoading = false;
                    }
                    break;
                case 'updateDashboard':
                    if (data.data) {
                        this.myCode = data.data.myCode || 'Lade...';
                        this.invitedPlayers = data.data.invitedPlayers || [];
                        this.rewards = data.data.rewards || [];
                        this.unlockedRewardIds = data.data.unlockedRewardIds || [];
                        this.hasReferredSomeone = data.data.hasReferredSomeone || false;
                        this.resetMessages();
                    }
                    this.isLoading = false;
                    break;
                case 'updateInitialData':
                    this.myCode = data.code || 'Lade...';
                    this.hasReferredSomeone = data.hasReferred || false;
                    break;
                case 'updateHasReferredStatus':
                    this.hasReferredSomeone = data.hasReferred;
                    break;
                case 'showError':
                    this.message = { text: data.message || "Ein unbekannter Fehler ist aufgetreten.", type: 'error' };
                    this.isLoading = false;
                    break;
            }
        },
        async submitCode() {
            if (!this.enteredCode.trim()) {
                this.message = { text: 'Bitte gib einen Code ein.', type: 'error' };
                return;
            }
            this.isSubmitting = true;
            this.resetMessages();
            try {
                const response = await this.postNuiMessage('submitReferralCode', { code: this.enteredCode });
                if (response.status === 'ok') {
                    this.message = { text: response.message || 'Code erfolgreich eingelöst!', type: 'success' };
                    this.enteredCode = '';
                } else {
                    this.message = { text: response.message || 'Fehler beim Einlösen des Codes.', type: 'error' };
                }
            } catch (error) {
                // Fehler wurde bereits in postNuiMessage behandelt
            } finally {
                this.isSubmitting = false;
            }
        },
        closeNUI() {
            this.postNuiMessage('closeNUI', {}).catch(err => {});
        },
        resetMessages() {
            this.message = { text: '', type: '' };
            this.copyMessage = '';
        },
        copyCode() {
            if (!this.myCode || this.myCode === 'Lade...') return;
            navigator.clipboard.writeText(this.myCode).then(() => {
                this.copyMessage = 'Code kopiert!';
                setTimeout(() => this.copyMessage = '', 2500);
            }).catch(err => {
                this.copyMessage = 'Fehler beim Kopieren.';
                setTimeout(() => this.copyMessage = '', 2500);
            });
        },
        isRewardUnlocked(reward) {
            const rewardIndex = this.rewards.findIndex(r => r.label === reward.label && r.required_referrals === reward.required_referrals);
            if (rewardIndex === -1) return false;
            const safeRewardValue = String(reward.reward_value).replace(/\./g, '_');
            const generatedRewardId = `reward_${rewardIndex + 1}_${reward.reward_type}_${safeRewardValue}`;
            return this.unlockedRewardIds.includes(generatedRewardId);
        }
    },
    mounted() {
        window.addEventListener('message', this.handleNuiMessages.bind(this));
        setTimeout(() => {
            this.postNuiMessage('nuiReady', {}).catch(error => {
                // Fehler wird bereits in postNuiMessage behandelt
            });
        }, 500);
    },
    beforeDestroy() {
        window.removeEventListener('message', this.handleNuiMessages.bind(this));
    },
    watch: {
        currentTab() {
            if (this.visible) {
                this.resetMessages();
            }
        },
        visible(newVal, oldVal) {
            if (newVal === true && oldVal === false) {
                this.isLoading = true;
                this.currentTab = 'startseite';
                this.resetMessages();
            }
        }
    }
});